package com.bookbot;

import com.sun.jna.PointerType;

public class Model extends PointerType implements AutoCloseable {
    public Model() {
    }

    public Model(String path) {
        super(LibBookbot.bookbot_model_new(path));
    }

    @Override
    public void close() {
        LibBookbot.bookbot_model_free(this.getPointer());
    }
}
