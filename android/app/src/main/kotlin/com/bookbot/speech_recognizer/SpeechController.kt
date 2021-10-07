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
import com.google.android.exoplayer2.ExoPlayer
import com.google.android.exoplayer2.MediaItem
import com.google.android.exoplayer2.Player
import com.google.android.exoplayer2.SimpleExoPlayer
import io.flutter.FlutterInjector
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.PluginRegistry
import timber.log.Timber

class SpeechController(context: Activity, private val lifecycle: Lifecycle): FlutterPlugin, MethodChannel.MethodCallHandler,
        PluginRegistry.RequestPermissionsResultListener, LifecycleObserver, SpeechListener, ActivityAware {
    private val methodChannel = "com.bookbot/control"
    private val eventChannelName = "com.bookbot/event"
    private val permissionRequestCode = 1

    private val soundNode: SimpleExoPlayer = SimpleExoPlayer.Builder(context).build()
    private val voiceNode: SimpleExoPlayer = SimpleExoPlayer.Builder(context).build()
    private val loopNode: SimpleExoPlayer = SimpleExoPlayer.Builder(context).build()
    private var eventSink: EventChannel.EventSink? = null
    private var _listen = false

    private var authorizeMethodResult: MethodChannel.Result? = null
    
    private var speechRecognitionService: SpeechService? = null
    private var speechRecognitionLanguage : String? = null
   
    private var methodResult: MethodChannel.Result? = null
    private lateinit var channel : MethodChannel
    private lateinit var eventChannel: EventChannel
    private var currentActivity: Activity? = context
    private val handler = Handler(Looper.getMainLooper())
    private var wasPlayingLoop = false
    private var wasListening = false
    private var lock = Object()
    ///
    /// The transcript of the speech that we expect to receive from the user once startListening/unmute
    /// is called.
    ///
    private var expectedSpeech:String? = null

    @Volatile private var isPlayingAudio = false
    private val playingTimer = Handler(Looper.getMainLooper())
    private val playingRunnable = object: Runnable {
        override fun run() {
            isPlayingAudio = soundNode.isPlaying || voiceNode.isPlaying
            val isListening = speechRecognitionService?.isRunning ?: false
            if(isPlayingAudio && isListening && !isCheckingSpeechStatus) {
                isCheckingSpeechStatus = true
                Timber.d("start checking speech status")
                Thread(speechRunnable).start()
            }
            playingTimer.postDelayed(this, 50)
        }
    }

    @Volatile private var isCheckingSpeechStatus = false
    private val speechRunnable = Runnable {
        speechRecognitionService?.pause()
        while (isPlayingAudio) {
//            Timber.d("audio is playing")
        }
        speechRecognitionService?.resume()
        isCheckingSpeechStatus = false
    }

    private var listen: Boolean
        get() = _listen
        set(value) {
            _listen = value
            if(value) {
                playingLoop = false
                startSpeech()
            } else {
                stopSpeech()
            }
        }

    private var playingLoop: Boolean
        get() = loopNode.isPlaying
        set(value) {
            if(value) {
                if(!loopNode.isPlaying && lifecycle.currentState.isAtLeast(Lifecycle.State.RESUMED)) {
                    loopNode.play()
                }
                if(listen) {
                    listen = false
                }
            } else {
                if(loopNode.isPlaying) {
                    loopNode.pause()
                }
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

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>?, grantResults: IntArray?): Boolean {
        if(requestCode == permissionRequestCode) {
            grantResults?.let {
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
            "initAudio" -> initAudio(result)
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
                expectedSpeech = call.arguments as String
                flushSpeech()
                result.success(null)
            }
            "cacheSounds" -> cacheSounds(result)
            "playSound" -> playSound(call.arguments as List<String>, result)
            "endSpeechSound" -> fadeout(voiceNode, false, result)
            "playLoop" -> playLoop(call.arguments as String, result)
            "endLoop" -> fadeout(loopNode, true, result)
            "endSpeech" -> endSpeech(result)
            else -> result.notImplemented()
        }
    }

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
        Thread { checkToStartSpeech() }.start()
    }

    private fun checkToStartSpeech() {
        while(isPlayingAudio)
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

    private fun initAudio(result: MethodChannel.Result) {
        loopNode.volume = loopNode.volume / 4
        loopNode.repeatMode = Player.REPEAT_MODE_ALL
        result.success(null)
    }

    /// 
    /// Unpacks/loads the acoustic/language model into the Kaldi service and, if a profile ID is specified.
    /// This does not actually start speech recognition - [startSpeech] must be called before doing so.
    /// This is entirely synchronous.
    ///
    private fun initSpeech(args: List<String?>, result: MethodChannel.Result?) {
        Thread {
            currentActivity?.let { activity ->
                synchronized(lock) {
                    val asrLanguage = args[0] ?: ""

                    if(speechRecognitionService == null || asrLanguage != this.speechRecognitionLanguage) {

                        // If a profile ID is provided, we pass exposeAudio as true when creating the VoskSpeechService
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
        playingTimer.postDelayed(playingRunnable, 500)
    }

    /// 
    /// (Asynchronously) starts speech recognition. 
    /// IMPORTANT - currently, there is no callback mechanism for [startSpeech] to indicate to the app that is actually listening. 
    /// Since this method returns prior to the decoding thread actually starting, this means successive calls to startSpeech can cause multiple decoding threads to spawn, which will crash the 
    /// app).
    ///
    private fun startSpeech() {
        synchronized(lock) {
            if(speechRecognitionService == null) {
                Timber.i("speechRecognitionService is null, startSpeech is a no-op")
            }
            speechRecognitionService?.start()
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
        playingTimer.removeCallbacks(playingRunnable)
        result.success(null)
    }

    private fun cacheSounds(result: MethodChannel.Result) {
        result.success(null)
    }

    private fun playSound(params: List<String>, result: MethodChannel.Result) {
        val context = currentActivity
        if (!lifecycle.currentState.isAtLeast(Lifecycle.State.RESUMED) || context == null) {
            result.success(null)
            return
        }
        
        if (!lifecycle.currentState.isAtLeast(Lifecycle.State.RESUMED)) {
            Timber.i("should not play sound in background")
            return
        }

        val path = params[0]
        val start = params[1].toDoubleOrNull() ?: 0.0
        val end = params[2].toDoubleOrNull() ?: 0.0
        val loader = FlutterInjector.instance().flutterLoader()
        val assetKey = loader.getLookupKeyForAsset(path)

        // Right now, we have some assets with filenames that are escaped URI paths (e.g. "%25ACfoo.m4a")
        // Flutter escapes these during the build process (becoming "%2525ACfoo.m4a") 
        // However, ExoPlayer seems to unescape all URIs no matter what, so we need to escape this one more time ("%252525ACfoo.m4a") to work properly with ExoPlayer
        // This is not ideal - it would be far better for all media assets to have alphanumeric filenames.
        val fullUri = "asset:///${assetKey.replace("%", "%2525")}"
        Timber.i("exoplayer playSound with path [$path] and uri $fullUri")
        val sound = MediaItem.fromUri(fullUri)
        // check if asset is sound (from assets/sounds/) and using another player
        val isSoundAsset = assetKey.contains("assets/sounds/")
        val audioNode = if(isSoundAsset) soundNode else voiceNode // this was introduced elsewhere so I have merged in, but not sure why we are doing this. Some comments could help.
        if(audioNode.isPlaying) {
            audioNode.stop()
            Timber.i("audioNode $fullUri is playing, stop")
        }
        sound.let { audioNode.setMediaItem(it) }
        audioNode.prepare()
        val isPlayingLoop = loopNode.isPlaying
        var started = false

        val listener = object: Player.Listener {
            override fun onPlayWhenReadyChanged(playWhenReady: Boolean, reason: Int) {
                Timber.i("onPlayWhenReadyChanged: $playWhenReady")
            }

            override fun onPlayerStateChanged(playWhenReady: Boolean, playbackState: Int) {

            }

            override fun onPlaybackStateChanged(state: Int) {
                Timber.i("onPlaybackStateChanged $state")
                when(state) {
                    ExoPlayer.STATE_ENDED -> {
                        audioNode.removeListener(this)
                        if(isPlayingLoop) {
                            playingLoop = true
                        }
                    }
                    ExoPlayer.STATE_READY -> {
                        if(audioNode.playWhenReady && audioNode.isPlaying) {
                            if(playingLoop) {
                                playingLoop = false
                            }

                            if(!started) {
                                started = true
                                result.success(null)
                                if(end != 0.0) {
                                    Timber.d("Schedule audio end at $end")
                                    handler.postDelayed({
                                        if(audioNode.isPlaying) {
                                            Timber.d("Stop audio")
                                            audioNode.stop()
                                        }
                                    }, (kotlin.math.abs(end - start) * 1000).toLong())
                                }
                            }

                        }
                    }
                    Player.STATE_BUFFERING -> {}
                    Player.STATE_IDLE -> {}
                }
            }
        }

        audioNode.addListener(listener)
        if(start != 0.0) {
            audioNode.seekTo((start * 1000).toLong())
            Timber.d("Audio starting at $start")
        }

        audioNode.play()
    }

    private fun fadeout(player: SimpleExoPlayer, pause: Boolean, result: MethodChannel.Result) {
        
        val volume = player.volume
        Timber.i("fadeout volume $volume")
        val partial = volume / 10
        for (i in 1..10) {
            Thread.sleep(30)
            player.volume -= partial
        }

        player.volume = 0.0f
        if(pause) {
            player.pause()
        } else {
            player.stop()
        }

        player.volume = volume
        result.success(null) 
    }

    private fun playLoop(path: String, result: MethodChannel.Result) {
        Timber.i("playLoop $path")
        if (!lifecycle.currentState.isAtLeast(Lifecycle.State.RESUMED)) {
            Timber.i("should not play loop sound in background")
            return
        }
        if(!loopNode.isPlaying) {
            val audio = MediaItem.fromUri("asset:///flutter_assets/$path")
            loopNode.setMediaItem(audio)
            loopNode.prepare()
            loopNode.volume = 0.5f
            loopNode.play()
        }

        result.success(null)
    }

    @Suppress("unused")
    @OnLifecycleEvent(Lifecycle.Event.ON_DESTROY)
    fun onDestroy() {
        Timber.d("onDestroy")
        loopNode.stop()
        loopNode.release()
        soundNode.stop()
        soundNode.release()
        voiceNode.stop()
        voiceNode.release()
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
        if(loopNode.isPlaying) {
            playingLoop = false
            wasPlayingLoop = true
        }

        if(soundNode.isPlaying) {
            soundNode.pause()
        }

        if(voiceNode.isPlaying) {
            voiceNode.pause()
        }
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
        if(loopNode.isPlaying) {
            playingLoop = false
            wasPlayingLoop = true
        }

        if(soundNode.isPlaying) {
            soundNode.pause()
        }

        if(voiceNode.isPlaying) {
            voiceNode.pause()
        }
    }

    override fun onSpeechResult(result: String) {
        if(listen) {
            eventSink?.success(result)
        }
    }

    override fun onSpeechError(error: Throwable, isEngineError: Boolean, isBusy: Boolean) {
        speechRecognitionService?.restart(if (isBusy) 500 else 0)
    }
}
