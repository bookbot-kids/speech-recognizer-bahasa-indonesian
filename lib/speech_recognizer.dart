// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';

enum AudioSpeechPermission { undetermined, authorized, denied, unknown }

abstract class SpeechListener {
  void onResult(Map result);
}

// initSpeech will setup the speech recognition system for the first time
// -> by adding the microphone to the audio system. It does not start the speech recognition
// The microphone is left on once it is turned on
// This is called when the book is opened
// The init is then ignored other times the book is opened
// listen/stop listening is to start/stop the speech recognition
// the mute/unmute is to pause the microphone, not the speech recognition
// it’s for when the bot is speaking and saying different things.
// There is also automatic muting when there is bot speaking
class SpeechController {
  SpeechController._privateConstructor();

  static SpeechController shared = SpeechController._privateConstructor();

  final methodChannel = const MethodChannel('com.bookbot/control');
  final eventChannel = const EventChannel('com.bookbot/event');
  final listeners = <SpeechListener>[];

  void addListener(SpeechListener listener) {
    if (!listeners.contains(listener)) {
      listeners.add(listener);
    }
  }

  void removeListener(SpeechListener listener) {
    listeners.remove(listener);
  }

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

  Future<void> authorize() async {
    try {
      final result = await methodChannel.invokeMethod('authorize');
      print('Authorize result $result');
    } catch (e) {
      print('Authorize error $e');
    }
  }

  Future<void> initAudio() async {
    await methodChannel.invokeMethod('initAudio');
  }

  Future<bool> isAudioInitialized() async {
    return await methodChannel.invokeMethod('isAudioInitialized');
  }

  Future<void> initSpeech(String language) async {
    await methodChannel.invokeMethod('initSpeech', [language]);
    eventChannel
        .receiveBroadcastStream()
        .listen(_onEvent, onError: _onEventError);
  }

  /// Decode JSON transcript stream and send to speech manager to handle
  void _onEvent(dynamic event) {
    final jsonData = json.decode(event);
    for (final listener in listeners) {
      listener.onResult(jsonData);
    }
  }

  void _onEventError(Object error) {
    print('Speech error $error');
  }

  Future<void> listen() async {
    await methodChannel.invokeMethod('listen');
  }

  Future<void> stopListening() async {
    await methodChannel.invokeMethod('stopListening');
  }

  Future<void> mute() async {
    await methodChannel.invokeMethod('mute');
  }

  Future<void> unmute() async {
    await methodChannel.invokeMethod('unmute');
  }

  Future<void> flushSpeech({String toRead = ''}) async {
    await methodChannel.invokeMethod('flushSpeech', toRead);
  }

  Future<void> cacheSounds() async {
    await methodChannel.invokeMethod('cacheSounds');
  }

  Future<void> playSound(String path,
      {double start = 0.0, double end = 0.0}) async {
    await methodChannel
        .invokeMethod('playSound', [path, start.toString(), end.toString()]);
  }

  Future<void> endSpeechSound() async {
    await methodChannel.invokeMethod('endSpeechSound');
  }

  Future<void> playLoop(String name) async {
    await methodChannel.invokeMethod('playLoop', name);
  }

  Future<void> endLoop() async {
    await methodChannel.invokeMethod('endLoop');
  }

  Future<void> endSpeech() async {
    if (Platform.isAndroid) {
      await methodChannel.invokeMethod('endSpeech');
    }
  }
}
