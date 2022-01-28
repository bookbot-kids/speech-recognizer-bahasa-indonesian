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