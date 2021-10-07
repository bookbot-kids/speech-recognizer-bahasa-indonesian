package com.bookbot.speech_recognizer.service

import android.content.Context
import android.os.Handler
import android.os.Looper
import com.bookbot.vosk.StreamWritingVoskService
import org.vosk.Model
import org.vosk.Recognizer
import org.vosk.android.StorageService
import timber.log.Timber
import java.util.concurrent.BlockingQueue

class VoskSpeechService(private val context: Context, private val language:String, private val exposeAudio:Boolean): SpeechService {
    private lateinit var listener: SpeechListener
    private var kaldiSpeechService: StreamWritingVoskService? = null
    override var buffer: BlockingQueue<ShortArray>? = null

    @Volatile
    private var initializedSpeech = false

    override var isRunning:Boolean = false
    get() = kaldiSpeechService?.isRunning ?: false

    private var stopped = true
    private var handler = Handler(Looper.getMainLooper())
    private val kaldiListener = KaldiSpeechListener()

    private val models:Map<String,String> = mapOf("en" to "model-en-us", "id" to "model-id-id")

    override fun initSpeech(listener: SpeechListener) {
        Timber.i("vosk initSpeech")
        if(initializedSpeech) {
            return
        }

        this.listener = listener
        initModel()
    }

    override fun start() {
        if(!initializedSpeech) {
          throw Exception("initializedSpeech is not true. Did you wait for initModel to complete?")
        }
        if(kaldiSpeechService?.startListening(kaldiListener) == false) {
            Timber.e("Could not start Kaldi speech service, this indicates a decoder thread is already running")    
        }
        stopped = false
        Timber.i("vosk speech start")
    }

    override fun pause() {
      if(!stopped && initializedSpeech) {
        kaldiSpeechService?.setPause(true)
      }
    }

    override fun resume() {
      if(!stopped && initializedSpeech) {
        kaldiSpeechService?.setPause(false)
      }
    }

    override fun stop() {
        if(!initializedSpeech) {
            return
        }

        isRunning = false
        stopped = true
        kaldiSpeechService?.stop()
        Timber.i("vosk speech stop")
    }

    override fun destroy() {
        if(!initializedSpeech) {
            return
        }

        stop()
        kaldiSpeechService?.shutdown()
        initializedSpeech = false
        Timber.i("vosk speech destroy")
    }

    override fun restart(time: Long) {
        if(!initializedSpeech || stopped) {
            return
        }

        isRunning = false
        handler.postDelayed({
            start()
        }, time)
        Timber.i("vosk speech restart")
    }

    override fun cancel() {
        if(!initializedSpeech) {
            return
        }
        kaldiSpeechService?.cancel()
    }

    /// 
    /// Model loading by Vosk is asynchronous, but doesn't return a proper Future that we can await.
    /// For now, we just return immediately and assume that start() won't be called before this has completed. 
    /// If this causes issues, we will restructure to wait elsewhere.
    ///
    private fun initModel() {
        initializedSpeech = false
        Timber.e("Initializing model $language")
        val outputPath = StorageService.sync(context, models[language], models[language])
        val model = Model(outputPath)
        Timber.e("Unpacked!")
        val recognizer =  Recognizer(model, 16000.0f)
        kaldiSpeechService = StreamWritingVoskService(recognizer, 16000.0f, exposeAudio)
        buffer = kaldiSpeechService?.buffer
        initializedSpeech = true
    }

    private inner class KaldiSpeechListener: org.vosk.android.RecognitionListener {


        override fun onPartialResult(result: String?) {
            processResult(result)
            Timber.d("vosk onPartialResult [$result]")
        }

        override fun onResult(result: String?) {
            processResult(result)
            Timber.d("vosk onResult [$result]")
        }

        override fun onFinalResult(result: String?) {
            processResult(result)
            Timber.d("vosk onFinalResult [$result]")
        }

        override fun onError(ex: Exception?) {
            Timber.d("vosk onError ${ex?.message}")
            ex?.let { listener.onSpeechError(it, false) }
            isRunning = false
        }

        override fun onTimeout() {
            Timber.d("vosk onTimeout")
        }

        private fun processResult(result: String?) {
            result?.let { listener.onSpeechResult(it) }
        }
    }
}
