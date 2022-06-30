cmake_minimum_required(VERSION 3.4.1)  # for example
set(CMAKE_BUILD_TYPE DEBUG)
set(CMAKE_CXX_STANDARD 17)
include_directories(src/main/cpp)
include_directories(src/main/cpp/include)

link_directories(src/main/jniLibs/${ANDROID_ABI})

add_library(
        bookbot
        SHARED
        src/main/cpp/bookbot_recognizer.cc
        src/main/cpp/bookbot_api.cc
        src/main/cpp/model.cc
        src/main/cpp/language_model.cc
)

target_link_libraries(bookbot  -landroid -llog -lvosk)

#-l:libkaldi-base.so -l:libkaldi-chain.so -l:libkaldi-decoder.so -l:libkaldi-feat.so -l:libkaldi-fstext.so -l:libkaldi-gmm.so -l:libkaldi-hmm.so -l:libkaldi-ivector.so -l:libkaldi-lat.so -l:libkaldi-kws.so -l:libkaldi-lm.so -l:libkaldi-matrix.so -l:libkaldi-transform.so -l:libkaldi-tree.so -l:libkaldi-util.so -l:libkaldi-nnet.so -l:libkaldi-nnet2.so -l:libkaldi-nnet3.so -l:libkaldi-online2.so -l:libkaldi-sgmm2.so -l:libfst.so -l:libfstlookahead.so -l:libfstngram.so -l:libkaldi-rnnlm.so -l:libkaldi-cudamatrix.so




