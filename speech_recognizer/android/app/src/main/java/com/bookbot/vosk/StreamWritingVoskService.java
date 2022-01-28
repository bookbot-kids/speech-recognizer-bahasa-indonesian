// Copyright 2019 Alpha Cephei Inc.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//       http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

package com.bookbot.vosk;

import android.annotation.SuppressLint;
import android.media.AudioFormat;
import android.media.AudioRecord;
import android.media.MediaRecorder.AudioSource;
import android.os.Handler;
import android.os.Looper;

import com.bookbot.Recognizer;

import org.vosk.android.RecognitionListener;

import java.io.IOException;
import java.util.concurrent.BlockingQueue;

import timber.log.Timber;

/**
 * Service that records audio in a thread, passes it to a recognizer and emits
 * recognition results. Recognition events are passed to a client using
 * {@link RecognitionListener}
 * Copy of org.vosk.android.SpeechService
 *
 */
public class StreamWritingVoskService  {

    private Recognizer recognizer;

    private final RecognitionListener listener;

    private final int sampleRate;
    public final static float BUFFER_SIZE_SECONDS = 0.2f;
    private final int bufferSize;
    private AudioRecord recorder;

    /**
     *  A buffer to expose audio data for external consumption.
     */
    public BlockingQueue<short[]> buffer;

    /** 
    * The thread on which the recognizer will actually run. 
    */
    private RecognizerThread recognizerThread;

    private final Handler mainHandler = new Handler(Looper.getMainLooper());

    public boolean isRunning = false;

    @SuppressLint("MissingPermission")
    public void initRecorder() {
        recorder = new AudioRecord(
                AudioSource.VOICE_RECOGNITION, this.sampleRate,
                AudioFormat.CHANNEL_IN_MONO,
                AudioFormat.ENCODING_PCM_16BIT, bufferSize * 2);
    }

    /**
     * Creates speech service. Service holds the AudioRecord object, so you
     * need to call {@link #shutdown()} in order to properly finalize it.
     * 
     * @throws IOException thrown if audio recorder can not be created for some reason.
     */
    @SuppressLint("MissingPermission")
    public StreamWritingVoskService(float sampleRate, BlockingQueue<short[]> buffer, RecognitionListener listener) throws IOException {
        this.listener = listener;
        this.sampleRate = (int) sampleRate;
        this.buffer = buffer;

        bufferSize = Math.round(this.sampleRate * BUFFER_SIZE_SECONDS);

        initRecorder();

        if (recorder.getState() == AudioRecord.STATE_UNINITIALIZED) {
            recorder.release();
            throw new IOException(
                    "Failed to initialize recorder. Microphone might be already in use.");
        }

        recognizerThread = new RecognizerThread();
        recognizerThread.start();
    }

    /**
     * Starts recognition. Does nothing if recognition is active.
     *
     * @return true if recognition was actually started
     */
    public synchronized boolean startListening(Recognizer recognizer) {

        recognizerThread.setPause(true);

        while(!recognizerThread.canReplaceRecognizer) {
            Timber.d("waiting for pause to be acknowledged");
        }
        Timber.d("pause acknowledged");

        this.recognizer = recognizer;

        recognizerThread.setPause(false);
        Timber.d("unpaused");

        return true;
    }

    private boolean stopRecognizerThread() {
        if (null == recognizerThread)
            return false;

        try {
            recognizerThread.interrupt();
            recognizerThread.join();
        } catch (InterruptedException e) {
            // Restore the interrupted status.
            Thread.currentThread().interrupt();
        }

        recognizerThread = null;
        isRunning = false;
        return true;
    }


    /**
     * Shutdown the recognizer and release the recorder
     */
    public void shutdown() {
        recorder.release();
        stopRecognizerThread();
    }

    public void setPause(boolean paused) {
        if (recognizerThread != null) {
            recognizerThread.setPause(paused);
        }
    }

    /**
     * Resets recognizer in a thread, starts recognition over again
     */
    public void reset() {
        if (recognizerThread != null) {
            recognizerThread.reset();
        }
    }

    private final class RecognizerThread extends Thread {

        private int remainingSamples;
        private final int timeoutSamples;
        private final static int NO_TIMEOUT = -1;
        
        ///
        /// [paused] is set to true by default because the underlying thread 
        /// will generally start running before any recognizer has been created/ready.
        /// This is because a new recognizer is created for every new passage of text.
        ///
        private volatile boolean canReplaceRecognizer = false;
        private volatile boolean paused = true;

        private volatile boolean reset = false;

        public RecognizerThread(int timeout) {
            if (timeout != NO_TIMEOUT)
                this.timeoutSamples = timeout * sampleRate / 1000;
            else
                this.timeoutSamples = NO_TIMEOUT;
            this.remainingSamples = this.timeoutSamples;
        }

        public RecognizerThread() {
            this(NO_TIMEOUT);
        }

        /**
         * When we are paused, don't process audio by the recognizer and don't emit
         * any listener results
         *
         * @param paused the status of pause
         */
        public void setPause(boolean paused) {
            this.paused = paused;
        }

        /**
         * Set reset state to signal reset of the recognizer and start over
         */
        public void reset() {
            this.reset = true;
        }

        @Override
        public void run() {
            // init recorder again if it's stopped
            if (recorder.getState() != AudioRecord.STATE_INITIALIZED) {
                recorder.release();
                Timber.d("startRecording() called on an uninitialized AudioRecord.");
                initRecorder();
            }

            recorder.startRecording();
            if (recorder.getRecordingState() == AudioRecord.RECORDSTATE_STOPPED) {
                recorder.stop();
                IOException ioe = new IOException(
                        "Failed to start recording. Microphone might be already in use.");
                mainHandler.post(() -> listener.onError(ioe));
            }

            short[] tmpBuffer = new short[bufferSize];

            isRunning = true;

            while (!interrupted()
                    && ((timeoutSamples == NO_TIMEOUT) || (remainingSamples > 0))) {

                if (paused) {
                    canReplaceRecognizer = true;
//                    Timber.d("vosk speech is paused");
                    continue;
                }

                if(recognizer == null) {
                    Timber.d("recognizer is not yet ready");
                    continue;
                }

                canReplaceRecognizer = false;

                int nread = recorder.read(tmpBuffer, 0, tmpBuffer.length);
                if(buffer != null) {
                    try {
                        buffer.put(tmpBuffer);
                    } catch(InterruptedException e) {
                        mainHandler.post(() -> listener.onError(e));
                        Thread.currentThread().interrupt();
                    }
                }

                if (reset) {
                    recognizer.reset();
                    reset = false;
                }

                if (nread < 0)
                    throw new RuntimeException("error reading audio buffer");

                if (recognizer.acceptWaveForm(tmpBuffer, nread)) {
                    final String result = recognizer.getResult();
                    mainHandler.post(() -> listener.onResult(result));
                } else {
                    final String partialResult = recognizer.getPartialResult();
                    mainHandler.post(() -> listener.onPartialResult(partialResult));
                }

                if (timeoutSamples != NO_TIMEOUT) {
                    remainingSamples = remainingSamples - nread;
                }
            }

            if (recorder.getState() == AudioRecord.STATE_INITIALIZED) {
                recorder.stop();
            } else {
                recorder.release();
            }


            if (!paused) {
                // If we met timeout signal that speech ended
                if (timeoutSamples != NO_TIMEOUT && remainingSamples <= 0) {
                    mainHandler.post(() -> listener.onTimeout());
                } else {
                    final String finalResult = recognizer.getFinalResult();
                    mainHandler.post(() -> listener.onFinalResult(finalResult));
                }
            }

        }
    }
}
