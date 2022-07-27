/*
Copyright 2022 [PT BOOKBOT INDONESIA](https://bookbot.id/)

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/

package com.bookbot.speech_recognizer

import android.Manifest
import android.app.Activity
import android.content.pm.PackageManager
import android.os.Handler
import android.os.Looper
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleObserver
import androidx.lifecycle.OnLifecycleEvent
import com.bookbot.speech_recognizer.service.SpeechListener
import com.bookbot.speech_recognizer.service.SpeechService
import com.bookbot.speech_recognizer.service.VoskSpeechService
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.PluginRegistry
import timber.log.Timber
import java.util.*

class SpeechController(context: Activity, private val lifecycle: Lifecycle): FlutterPlugin, MethodChannel.MethodCallHandler,
        PluginRegistry.RequestPermissionsResultListener, LifecycleObserver, SpeechListener, ActivityAware {
    private val methodChannel = "com.bookbot/control"
    private val eventChannelName = "com.bookbot/event"
    private val permissionRequestCode = 1

    private var eventSink: EventChannel.EventSink? = null
    private var _listen = false

    private var authorizeMethodResult: MethodChannel.Result? = null
    
    private var speechRecognitionService: SpeechService? = null
    private var speechRecognitionLanguage : String? = null
    private lateinit var channel : MethodChannel
    private lateinit var eventChannel: EventChannel
    private var currentActivity: Activity? = context
    private val handler = Handler(Looper.getMainLooper())
    private var wasListening = false
    private var lock = Object()

    ///
    /// The transcript of the speech that we expect to receive from the user once startListening/unmute
    /// is called.
    ///
    private var expectedSpeech:String? = null

    ///
    /// The grammar passed to the recognizer. Usually a superset of [expectedSpeech].
    ///
    private var grammar:String? = null


    private var listen: Boolean
        get() = _listen
        set(value) {
            _listen = value
            if(value) {
                startSpeech()
            } else {
                stopSpeech()
            }
        }


    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(binding.binaryMessenger, methodChannel)
        channel.setMethodCallHandler(this)

        eventChannel = EventChannel(binding.binaryMessenger, eventChannelName)
        eventChannel.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                eventSink = events
            }

            override fun onCancel(arguments: Any?) {}
        })
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ): Boolean {
        if(requestCode == permissionRequestCode) {
            grantResults.let {
                if(it[0] == PackageManager.PERMISSION_GRANTED) {
                    authorizeMethodResult?.success("authorized")
                } else {
                    authorizeMethodResult?.success("denied")
                }

                authorizeMethodResult = null
            }
        }

        return false
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        currentActivity = binding.activity
        binding.addRequestPermissionsResultListener(this)
    }

    override fun onDetachedFromActivityForConfigChanges() {
        currentActivity = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        currentActivity = binding.activity
        binding.addRequestPermissionsResultListener(this)
    }

    override fun onDetachedFromActivity() {
        currentActivity = null
    }

    @Suppress("UNCHECKED_CAST")
    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        Timber.i("call method ${call.method} with argument ${call.arguments}")
        when (call.method) {
            "audioPermission" -> audioPermission(result)
            "authorize" -> authorize(result)
            "initSpeech" -> initSpeech(call.arguments as List<String?>, result)
            "listen" -> {
                listen = true
                result.success(null)
            }
            "stopListening" -> {
                listen = false
                result.success(null)
            }
            "mute" -> {
                listen = false
                result.success(null)
            }
            "unmute" -> {
                listen = true
                result.success(null)
            }
            "flushSpeech" -> {
                // when flushSpeech is called, a String is passed containing the text of what we expect to hear from the user next
                val args = call.arguments as ArrayList<Any?>
                expectedSpeech = args[0] as String?
                grammar = args[1] as String?
                flushSpeech()
                result.success(null)
            }
            "endSpeech" -> endSpeech(result)
            else -> result.notImplemented()
        }
    }

    /// 
    /// Synchronously stops speech recognition (and the microphone recorder), then asynchronously starts speech recognition half a second later.
    /// This effectively resets the Vosk speech recognition buffer, so should be used whenever you expect an utterance to have completed, and want to decode a new utterance.
    /// IMPORTANT - this is not synchronized, and may cause concurrency issues when interleaved with calls to [startSpeech].
    /// TODO - there needs to be some app-side mechanism to ensure that flushSpeech is not called prior to [startSpeech] completing (see [startSpeech])
    ///
    private fun flushSpeech() {
        if(speechRecognitionService == null) {
            Timber.e("speechRecognitionService is null, ignoring call to flushSpeech");
            return
        } else if(speechRecognitionService?.isRunning != true) {
            Timber.e("speechRecognitionService is not running, ignoring call to flushSpeech");
            return
        }

        Timber.d("flushSpeech stopSpeech")
        stopSpeech()
        startSpeech()
    }

    private fun audioPermission(result: MethodChannel.Result) {
        currentActivity?.let {
            if(ContextCompat.checkSelfPermission(it, Manifest.permission.RECORD_AUDIO) != PackageManager.PERMISSION_GRANTED) {
                result.success("undetermined")
            } else {
                result.success("authorized")
            }
        } ?: run {
            result.success("undetermined")
        }
    }

    private fun authorize(result: MethodChannel.Result) {
        if(authorizeMethodResult != null) return
        currentActivity?.let {
            authorizeMethodResult = result
            ActivityCompat.requestPermissions(it, arrayOf(Manifest.permission.RECORD_AUDIO), permissionRequestCode)
        }
    }

    /// 
    /// Unpacks/loads the acoustic/language model into the Kaldi service and, if a profile ID is specified, creates a recorder to store/encode audio from the microphone.
    /// This does not actually start speech recognition - [startSpeech] must be called before doing so.
    ///
    private fun initSpeech(args: List<String?>, result: MethodChannel.Result?) {
        Thread {
            currentActivity?.let { activity ->
                synchronized(lock) {

                    val asrLanguage = args[0] ?: ""
                    if(speechRecognitionService == null || asrLanguage != this.speechRecognitionLanguage) {
                        // If a profile ID is provided, we pass exposeAudio as true when creating the VoskSpeechService and pass its buffer to a MicrophoneRecorder instance
                        speechRecognitionService?.destroy()
                        speechRecognitionService = VoskSpeechService(activity, asrLanguage, false)
                        speechRecognitionLanguage = asrLanguage
                        speechRecognitionService?.initSpeech(this)
                    } else {
                        Timber.d("SpeechRecognitionService already exists for this language and profile ID, skipping re-creation")
                    }
                    Timber.d("Speech recognition initialization complete.")
                }
            }
        }.start()
        result?.success(null)
    }

    /// 
    /// (Asynchronously) starts speech recognition. 
    /// IMPORTANT - currently, there is no callback mechanism for [startSpeech] to indicate to the app that is actually listening. 
    /// Since this method returns prior to the decoding thread actually starting, this means successive calls to startSpeech can cause multiple decoding threads to spawn, which will crash the 
    /// app).
    ///
    private fun startSpeech() {
        if(speechRecognitionService == null) {
            Timber.i("speechRecognitionService is null, startSpeech is a no-op")
        }
        grammar?.let {
            synchronized(lock) {
                speechRecognitionService?.start(it)
            }
        }
    }

    /// 
    /// (Synchronously) stops speech recognition. 
    ///
    private fun stopSpeech() {
        if(speechRecognitionService == null) {
            Timber.i("speechRecognitionService is null, stopSpeech is a no-op")
        }
        speechRecognitionService?.stop()
    }

    /// 
    /// (Synchronously) stops speech recognition and tears down the underlying service (i.e. unloads the model from memory).
    ///
    private fun endSpeech(result: MethodChannel.Result) {
        Timber.d("endSpeech")
        // TODO don't release the speech service to avoid crash atm
//        speechRecognitionService?.destroy()
//        speechRecognitionService = null
        result.success(null)
    }


    @Suppress("unused")
    @OnLifecycleEvent(Lifecycle.Event.ON_DESTROY)
    fun onDestroy() {
        Timber.d("onDestroy")
        speechRecognitionService?.destroy()
    }

    @Suppress("unused")
    @OnLifecycleEvent(Lifecycle.Event.ON_PAUSE)
    fun onPause() {
        Timber.d("onPause")
        if(listen) {
            wasListening = true
        }
        speechRecognitionService?.stop()
    }

    @Suppress("unused")
    @OnLifecycleEvent(Lifecycle.Event.ON_RESUME)
    fun onResume() {
        Timber.d("onResume")
        if(wasListening) {
            wasListening = false
           listen = true
        }
    }

    @Suppress("unused")
    @OnLifecycleEvent(Lifecycle.Event.ON_STOP)
    fun onStop() {
        Timber.d("onStop")
        if(listen) {
            wasListening = true
        }
        speechRecognitionService?.stop()
        listen = false
    }

    override fun onSpeechResult(result: String, wasEndpoint:Boolean) {
        if(listen) {
            eventSink?.success(listOf(result, wasEndpoint))
        }
    }

    override fun onSpeechError(error: Throwable, isEngineError: Boolean, isBusy: Boolean) {
        speechRecognitionService?.restart(if (isBusy) 500 else 0, expectedSpeech!!)
    }
}
