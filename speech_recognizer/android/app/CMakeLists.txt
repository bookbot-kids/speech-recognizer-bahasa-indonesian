cmake_minimum_required(VERSION 3.4.1)  # for example
set(CMAKE_BUILD_TYPE DEBUG)

set(ANDROID_STL c++_shared)
set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -std=c++14")

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

target_link_libraries(
  bookbot 
  -landroid 
  -llog 
  -lc++ 
  -l:kaldi-fstext.a 
  -l:kaldi-chain.a 
  -l:kaldi-nnet3.a 
  -l:kaldi-online2.a 
  -l:kaldi-feat.a 
  -l:kaldi-ivector.a 
  -l:kaldi-rnnlm.a 
  -l:kaldi-lm.a 
  -l:kaldi-decoder.a 
  -l:kaldi-lat.a 
  -l:kaldi-hmm.a 
  -l:kaldi-transform.a 
  -l:kaldi-gmm.a 
  -l:kaldi-tree.a 
  -l:kaldi-cudamatrix.a 
  -l:kaldi-matrix.a 
  -l:kaldi-util.a 
  -l:kaldi-base.a 
  -l:libopenblas.a 
  -l:libclapack.a 
  -l:libblas.a 
  -l:libf2c.a 
  -l:libfst.a 
  -l:libfstlookahead.a
  -l:libfstngram.a 
  -l:olabel_lookahead-fst.a 
  -l:ngram-fst.a )




