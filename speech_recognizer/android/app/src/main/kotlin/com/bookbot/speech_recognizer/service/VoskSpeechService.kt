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

package com.bookbot.speech_recognizer.service

import android.content.Context
import android.os.Handler
import android.os.Looper
import com.bookbot.vosk.StreamWritingVoskService
import org.vosk.android.RecognitionListener
import com.bookbot.Model
import com.bookbot.Recognizer
import com.bookbot.vosk.StorageService
import timber.log.Timber
import java.util.concurrent.BlockingQueue
import java.util.concurrent.ArrayBlockingQueue

class VoskSpeechService(private val context: Context, private val language:String, private val bufferAudio:Boolean):
    SpeechService {
    
    private lateinit var model: Model
    private lateinit var listener: SpeechListener
    private var kaldiSpeechService: StreamWritingVoskService? = null
    override var buffer: BlockingQueue<ShortArray>? = null

    ///
    /// Whether or not the model has been loaded and is ready to be started.
    ///
    @Volatile
    private var ready = false

    override var isRunning:Boolean = false
    get() = kaldiSpeechService?.isRunning ?: false

    ///
    /// Whether or not the recognition service has been instructed to stop (this is distinct from whether it has actually stopped).
    ///
    private var stopped = true

    private var handler = Handler(Looper.getMainLooper())
    private val kaldiListener = KaldiSpeechListener()

    private val numCandidates = 20

    private val models:Map<String,String> = mapOf("en" to "model-en-us", "id" to "model-id-id")

    override fun initSpeech(listener: SpeechListener) {
        Timber.i("vosk initSpeech")
        if(ready) {
            return
        }

        this.listener = listener
        initModel()
    }

    override fun start(grammar:String?) {
        if(!ready) {
          throw Exception("VoskSpeechService is not ready, did you wait for initModel to complete?")
        }
        Timber.e("Using grammar " + grammar)    

        val recognizer = grammar != null ? Recognizer(model!!, 16000.0f, grammar) : Recognizer(model!!, 16000.0f)

        recognizer.setMaxAlternatives(numCandidates)
        
        if(kaldiSpeechService!!.startListening(recognizer) == false) {
            Timber.e("Could not start Kaldi speech service, this indicates a decoder thread is already running")    
        }
        stopped = false
        Timber.i("vosk speech start")
    }

    override fun pause() {
      if(!stopped && ready) {
        kaldiSpeechService?.setPause(true)
      }
    }

    override fun resume() {
      if(!stopped && ready) {
        kaldiSpeechService?.setPause(false)
      }
    }

    override fun stop() {
        if(!ready) {
            return
        }
        stopped = true
        kaldiSpeechService?.setPause(true)
        Timber.i("vosk speech stop")
    }

    override fun destroy() {
        if(!ready) {
            return
        }

        stop()
        kaldiSpeechService?.shutdown()
        ready = false
        Timber.i("vosk speech destroy")
    }

    override fun restart(time: Long, expected:String) {
        if(!ready || stopped) {
            return
        }

        isRunning = false
        handler.postDelayed({
            start(expected)
        }, time)
        Timber.i("vosk speech restart")
    }

    /// 
    /// Model loading by Vosk is asynchronous, but doesn't return a proper Future that we can await.
    /// For now, we just return immediately and assume that start() won't be called before this has completed. 
    /// If this causes issues, we will restructure to wait elsewhere.
    ///
    private fun initModel() {
        ready = false
        Timber.e("Initializing model $language")
        val sourcePath =  models[language] ?: ""
        val outputPath = StorageService.sync(context, sourcePath, sourcePath)
        model = Model(outputPath)
        Timber.e("Unpacked!")
        if(bufferAudio) {
            this.buffer = ArrayBlockingQueue(1024);
        }
        kaldiSpeechService = StreamWritingVoskService(16000.0f, this.buffer, kaldiListener)

        ready = true
    }

    private inner class KaldiSpeechListener : RecognitionListener {

        override fun onPartialResult(result: String?) {
            processResult(result, false)
        }

        override fun onResult(result: String?) {
            processResult(result, true)
        }

        override fun onFinalResult(result: String?) {
            processResult(result, true)
        }

        override fun onError(ex: Exception?) {
            Timber.d("vosk onError ${ex?.message}")
            ex?.let { listener.onSpeechError(it, false) }
            isRunning = false
        }

        override fun onTimeout() {
            Timber.d("vosk onTimeout")
        }

        private fun processResult(result: String?, wasEndpoint: Boolean) {
            result?.let { listener.onSpeechResult(it, wasEndpoint) }
        }
    }
}
