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

import java.util.concurrent.BlockingQueue

interface SpeechListener {
    fun onSpeechResult(result: String, wasEndpoint: Boolean)
    fun onSpeechError(error: Throwable, isEngineError: Boolean, isBusy: Boolean = false)
}

interface SpeechService {
    val isRunning:Boolean
    fun initSpeech(listener: SpeechListener, startSpeech: Boolean = true)
    fun start(grammar:String?)
    fun stop()
    fun destroy()
    fun restart(time: Long, grammar:String)
    fun pause()
    fun resume()
    val buffer: BlockingQueue<ShortArray>?
    fun recognizeAudio(filePath: String): List<String>
}
