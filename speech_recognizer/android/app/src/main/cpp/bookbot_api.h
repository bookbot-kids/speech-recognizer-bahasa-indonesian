// Copyright 2020-2021 Alpha Cephei Inc.
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

/* This header contains the C API for Vosk speech recognition system */

#ifndef BOOKBOT_API_H
#define BOOKBOT_API_H

#ifdef __cplusplus
extern "C" {
#endif

/** Recognizer object is the main object which processes data.
 *  Each recognizer usually runs in own thread and takes audio as input.
 *  Once audio is processed recognizer returns JSON object as a string
 *  which represent decoded information - words, confidences, times, n-best lists,
 *  speaker information and so on */
typedef struct BookbotRecognizer BookbotRecognizer;

typedef struct BookbotModel BookbotModel;

/** Creates the recognizer object using the existing grammar.
 *
 *
 *  @param model       VoskModel containing static data for recognizer. Model can be
 *                     shared across recognizers, even running in different threads.
 *  @param sample_rate The sample rate of the audio you going to feed into the recognizer.
 *                     Make sure this rate matches the audio content, it is a common
 *                     issue causing accuracy problems.
 *
 *  @returns recognizer object or NULL if problem occured */
BookbotRecognizer *bookbot_recognizer_new(BookbotModel *model, float sample_rate);

/** Creates the recognizer object with the phrase list
 *
 *  Sometimes when you want to improve recognition accuracy and when you don't need
 *  to recognize large vocabulary you can specify a list of phrases to recognize. This
 *  will improve recognizer speed and accuracy but might return [unk] if user said
 *  something different.
 *
 *  Only recognizers with lookahead models support this type of quick configuration.
 *  Precompiled HCLG graph models are not supported.
 *
 *  @param model       VoskModel containing static data for recognizer. Model can be
 *                     shared across recognizers, even running in different threads.
 *  @param sample_rate The sample rate of the audio you going to feed into the recognizer.
 *                     Make sure this rate matches the audio content, it is a common
 *                     issue causing accuracy problems.
 *  @param grammar The string with the list of phrases to recognize as JSON array of strings,
 *                 for example "["one two three four five", "[unk]"]".
 *
 *  @returns recognizer object or NULL if problem occured */
BookbotRecognizer *bookbot_recognizer_new_grm(BookbotModel *model, float sample_rate, const char *grammar);


/** Configures recognizer to output n-best results
 *
 * <pre>
 *   {
 *      "alternatives": [
 *          { "text": "one two three four five", "confidence": 0.97 },
 *          { "text": "one two three for five", "confidence": 0.03 },
 *      ]
 *   }
 * </pre>
 *
 * @param max_alternatives - maximum alternatives to return from recognition results
 */
void bookbot_recognizer_set_max_alternatives(BookbotRecognizer *recognizer, int max_alternatives);



/** Accept voice data
 *
 *  accept and process new chunk of voice data
 *
 *  @param data - audio data in PCM 16-bit mono format
 *  @param length - length of the audio data
 *  @returns 1 if silence is occured and you can retrieve a new utterance with result method 
 *           0 if decoding continues
 *           -1 if exception occured */
int bookbot_recognizer_accept_waveform(BookbotRecognizer *recognizer, const char *data, int length);

int bookbot_recognizer_accept_waveform_s(BookbotRecognizer *recognizer, const short *data, int length);


/** Returns speech recognition result
 *
 * @returns the result in JSON format which contains decoded line, decoded
 *          words, times in seconds and confidences. You can parse this result
 *          with any json parser
 *
 * <pre>
 *  {
 *    "text" : "what zero zero zero one"
 *  }
 * </pre>
 *
 * If alternatives enabled it returns result with alternatives, see also vosk_recognizer_set_alternatives().
 *
 * If word times enabled returns word time, see also vosk_recognizer_set_word_times().
 */
const char *bookbot_recognizer_result(BookbotRecognizer *recognizer);


/** Returns partial speech recognition
 *
 * @returns partial speech recognition text which is not yet finalized.
 *          result may change as recognizer process more data.
 *
 * <pre>
 * {
 *    "partial" : "cyril one eight zero"
 * }
 * </pre>
 */
const char *bookbot_recognizer_partial_result(BookbotRecognizer *recognizer);


/** Returns speech recognition result. Same as result, but doesn't wait for silence
 *  You usually call it in the end of the stream to get final bits of audio. It
 *  flushes the feature pipeline, so all remaining audio chunks got processed.
 *
 *  @returns speech result in JSON format.
 */
const char *bookbot_recognizer_final_result(BookbotRecognizer *recognizer);


/** Resets the recognizer
 *
 *  Resets current results so the recognition can continue from scratch */
void bookbot_recognizer_reset(BookbotRecognizer *recognizer);


/** Releases recognizer object
 *
 *  Underlying model is also unreferenced and if needed released */
void bookbot_recognizer_free(BookbotRecognizer *recognizer);

BookbotModel *bookbot_model_new(const char *model_path);

void bookbot_model_free(BookbotModel *model);

#ifdef __cplusplus
}
#endif

#endif /* VOSK_API_H */
