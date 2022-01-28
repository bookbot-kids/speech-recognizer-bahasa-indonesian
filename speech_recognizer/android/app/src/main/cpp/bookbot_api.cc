// Copyright 2020 Alpha Cephei Inc.
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

#include "bookbot_api.h"
#include "bookbot_recognizer.h"
#include "model.h"

#include <string.h>

extern "C" {
    using namespace kaldi;

    BookbotModel *bookbot_model_new(const char *model_path)
    {
        try {
            return new BookbotModel(model_path);
        } catch (...) {
            
            return nullptr;
        }
    }

    void bookbot_model_free(BookbotModel *model)
    {
        if (model == nullptr) {
            return;
        }
        model->Unref();
    }

    int bookbot_model_find_word(BookbotModel *model, const char *word)
    {
        return (int) model->FindWord(word);
    }

    BookbotRecognizer *bookbot_recognizer_new_grm(BookbotModel *model, float sample_rate, const char *grammar)
    {
        try {
            return (BookbotRecognizer *)new BookbotRecognizer(model, sample_rate, grammar);
        } catch (...) {
            return nullptr;
        }
    }

    BookbotRecognizer *bookbot_recognizer_new(BookbotModel *model, float sample_rate)
    {
        try {
            return (BookbotRecognizer *)new BookbotRecognizer(model, sample_rate);
        } catch (...) {
            return nullptr;
        }
    }

    void bookbot_recognizer_set_max_alternatives(BookbotRecognizer *recognizer, int max_alternatives)
    {
        ((BookbotRecognizer *)recognizer)->SetMaxAlternatives(max_alternatives);
    }
        
    int bookbot_recognizer_accept_waveform_s(BookbotRecognizer *recognizer, const short *data, int length)
    {
        try {
            return ((BookbotRecognizer *)(recognizer))->AcceptWaveform(data, length);
        } catch (...) {
            return -1;
        }
    }

    const char *bookbot_recognizer_result(BookbotRecognizer *recognizer)
    {
        return ((BookbotRecognizer *)recognizer)->Result();
    }

    const char *bookbot_recognizer_partial_result(BookbotRecognizer *recognizer)
    {
        return ((BookbotRecognizer *)recognizer)->PartialResult();
    }

    const char *bookbot_recognizer_final_result(BookbotRecognizer *recognizer)
    {
        return ((BookbotRecognizer *)recognizer)->FinalResult();
    }

    void bookbot_recognizer_reset(BookbotRecognizer *recognizer)
    {
        ((BookbotRecognizer *)recognizer)->Reset();
    }

    void bookbot_recognizer_free(BookbotRecognizer *recognizer)
    {        
        delete (BookbotRecognizer *)(recognizer);
    }

}