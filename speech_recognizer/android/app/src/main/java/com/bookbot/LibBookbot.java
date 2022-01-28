package com.bookbot;

import com.sun.jna.Native;
import com.sun.jna.Library;
import com.sun.jna.Platform;
import com.sun.jna.Pointer;
import java.io.File;
import java.io.InputStream;
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.StandardCopyOption;

public class LibBookbot {

    static {
        Native.register(LibBookbot.class, "bookbot");
    }
    
    public static native Pointer bookbot_model_new(String path);

    public static native void bookbot_model_free(Pointer model);

    public static native Pointer bookbot_recognizer_new_grm(Pointer model, float sample_rate, String grammar);

    public static native void bookbot_recognizer_set_max_alternatives(Pointer recognizer, int max_alternatives);

    public static native boolean bookbot_recognizer_accept_waveform_s(Pointer recognizer, short[] data, int len);
                                
    public static native String bookbot_recognizer_result(Pointer recognizer);

    public static native String bookbot_recognizer_final_result(Pointer recognizer);

    public static native String bookbot_recognizer_partial_result(Pointer recognizer);

    public static native void bookbot_recognizer_reset(Pointer recognizer);

    public static native void bookbot_recognizer_free(Pointer recognizer);

}