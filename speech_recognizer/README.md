# Speech Recognizer

An Indonesian speech recognizer Flutter app for Android/iOS/MacOS. It will read buffer from microphone and recognize speaking words.

## Setup

- Install flutter sdk.
- Run `git lfs pull` command.
- Run the demo on Android/iOS/MacOS.

## Structure

- [`lib/speech_recognizer.dart`](lib/speech_recognizer.dart)
  - This is the interface API to communicate with native platform (android/iOS/Mac). There are many speech recognizer methods, check [`lib/main.dart`](lib/main.dart) to know how to use them.
- [`android/models/src/main/assets/model-id-id`](android/models/src/main/assets/model-id-id/)
  - This is the speech model that shared for all platforms. Replace `model-id-id/graph` to change the model dictionary.
- [`swift/SpeechController.swift`](swift/SpeechController.swift)
  - The native platform channel for speech recognizer on iOS/MacOS. It uses [Vosk](https://github.com/alphacep/vosk-api) with custom model.
- [`android/app/src/main/kotlin/com/bookbot/speech_recognizer/SpeechController.kt`](android/app/src/main/kotlin/com/bookbot/speech_recognizer/SpeechController.kt)
  - The native platform channel for speech recognizer on android. It uses [Vosk](https://github.com/alphacep/vosk-api) with custom model.
