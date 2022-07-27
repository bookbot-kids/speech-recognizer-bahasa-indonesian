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

package com.bookbot;

import com.sun.jna.PointerType;

public class Recognizer extends PointerType implements AutoCloseable {

    public Recognizer(Model model, float sampleRate, String grammar) {
        super(LibBookbot.bookbot_recognizer_new_grm(model.getPointer(), sampleRate, grammar));
    }

    public void setMaxAlternatives(int maxAlternatives) {
        LibBookbot.bookbot_recognizer_set_max_alternatives(this.getPointer(), maxAlternatives);
    }

    public boolean acceptWaveForm(short[] data, int len) {
        return LibBookbot.bookbot_recognizer_accept_waveform_s(this.getPointer(), data, len);
    }

    public String getResult() {
        return LibBookbot.bookbot_recognizer_result(this.getPointer());
    }

    public String getPartialResult() {
        return LibBookbot.bookbot_recognizer_partial_result(this.getPointer());
    }

    public String getFinalResult() {
        return LibBookbot.bookbot_recognizer_final_result(this.getPointer());
    }

    public void reset() {
        LibBookbot.bookbot_recognizer_reset(this.getPointer());
    }

    @Override
    public void close() {
        LibBookbot.bookbot_recognizer_free(this.getPointer());
    }
}