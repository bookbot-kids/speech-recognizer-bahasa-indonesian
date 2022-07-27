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

// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';

/// Audio permissions
enum AudioSpeechPermission {
  /// undetermined permission
  undetermined,

  /// user already grant permission
  authorized,

  // user denied permission
  denied,

  // unknown current permission
  unknown
}

/// Speech event listener
abstract class SpeechListener {
  /// Called when speech is recognized from the microphone
  /// [result] is the recognized text
  void onResult(Map result, bool wasEndPoint);
}

class SpeechController {
  SpeechController._privateConstructor();

  /// The singleton instance
  static SpeechController shared = SpeechController._privateConstructor();

  final methodChannel = const MethodChannel('com.bookbot/control');
  final eventChannel = const EventChannel('com.bookbot/event');
  final listeners = <SpeechListener>[];

  /// Register listener for speech events while speaking
  void addListener(SpeechListener listener) {
    if (!listeners.contains(listener)) {
      listeners.add(listener);
    }
  }

  /// Remove listener for speech events
  void removeListener(SpeechListener listener) {
    listeners.remove(listener);
  }

  /// Detect current permission for speech recognition
  Future<AudioSpeechPermission> permissions() async {
    final audioPermission = await methodChannel.invokeMethod('audioPermission');

    if (audioPermission == 'undetermined') {
      return AudioSpeechPermission.undetermined;
    }

    if (audioPermission == 'denied') {
      return AudioSpeechPermission.denied;
    }

    if (audioPermission == 'authorized') {
      return AudioSpeechPermission.authorized;
    }

    return AudioSpeechPermission.unknown;
  }

  /// Ask for microphone permission for speech recognition
  Future<void> authorize() async {
    try {
      final result = await methodChannel.invokeMethod('authorize');
      print('Authorize result $result');
    } catch (e) {
      print('Authorize error $e');
    }
  }

  /// Initialize speech recognition ML model
  Future<void> initSpeech(String language) async {
    await methodChannel.invokeMethod('initSpeech', [language]);
    eventChannel
        .receiveBroadcastStream()
        .listen(_onEvent, onError: _onEventError);
  }

  /// Decode JSON transcript stream and send to speech manager to handle
  void _onEvent(Object? event) {
    final args = event as List<dynamic>;
    final jsonResult = json.decode(args[0]);
    for (var listener in listeners) {
      listener.onResult(jsonResult, args[1] as bool);
    }
  }

  /// On speech event error from native
  void _onEventError(Object error) {
    print('Speech error $error');
  }

  /// Start speech recognition to listen microphone buffer
  Future<void> listen() async {
    await methodChannel.invokeMethod('listen');
  }

  /// Stop speech recognition
  Future<void> stopListening() async {
    await methodChannel.invokeMethod('stopListening');
  }

  /// Mute the micrphone
  Future<void> mute() async {
    await methodChannel.invokeMethod('mute');
  }

  /// Unmute the micrphone
  Future<void> unmute() async {
    await methodChannel.invokeMethod('unmute');
  }

  /// when flushSpeech is called, a string is passed containing the text of what we expect to hear from the user next
  /// The [toRead] is distinct from [grammar] because the former should be used as the audio clip recording transcript, whereas the latter needs to be for the speech recognition model.
  /// For example, if we expect the word "cat", then [toRead] is set to "cat" but [grammar] needs to be set to [cat, mat, sat] etc.
  /// Otherwise, the recognizer will only ever return the word "cat", no matter what was said.
  Future<void> flushSpeech({String toRead = '', String grammar = ''}) async {
    await methodChannel.invokeMethod('flushSpeech', [toRead, grammar]);
  }

  /// End speech recognition to release resources (just for android)
  Future<void> endSpeech() async {
    if (Platform.isAndroid) {
      await methodChannel.invokeMethod('endSpeech');
    }
  }
}
