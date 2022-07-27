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