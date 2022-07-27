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
