package com.bookbot.speech_recognizer.service

import java.util.concurrent.BlockingQueue

interface SpeechListener {
    fun onSpeechResult(result: String)
    fun onSpeechError(error: Throwable, isEngineError: Boolean, isBusy: Boolean = false)
}

interface SpeechService {
    val isRunning:Boolean
    fun initSpeech(listener: SpeechListener)
    fun start()
    fun stop()
    fun destroy()
    fun restart(time: Long)
    fun cancel()
    fun pause()
    fun resume()
    val buffer: BlockingQueue<ShortArray>?
}
