# Speech Recognizer Bahasa Indonesia

A Bahasa Indonesian speech recognizer platform, written in Flutter.

## Speech Recognizer

An Indonesian speech recognizer Flutter app for Android/iOS/MacOS. It will read buffer from microphone and recognize speaking words.

### Setup

- Install flutter sdk.
- Run `git lfs pull` command.
- Run the demo on Android/iOS/MacOS.

### Structure

- [`lib/speech_recognizer.dart`](speech_recognizer/lib/speech_recognizer.dart)
  - This is the interface API to communicate with native platform (android/iOS/Mac). There are many speech recognizer methods, check [`lib/main.dart`](speech_recognizer/lib/main.dart) to know how to use them.
- [`android/models/src/main/assets/model-id-id`](speech_recognizer/android/models/src/main/assets/model-id-id/)
  - This is the speech model that shared for all platforms. Replace `model-id-id/graph` to change the model dictionary.
- [`swift/SpeechController.swift`](speech_recognizer/swift/SpeechController.swift)
  - The native platform channel for speech recognizer on iOS/MacOS. It uses [Vosk](https://github.com/alphacep/vosk-api) with custom model.
- [`android/app/src/main/kotlin/com/bookbot/speech_recognizer/SpeechController.kt`](speech_recognizer/android/app/src/main/kotlin/com/bookbot/speech_recognizer/SpeechController.kt)
  - The native platform channel for speech recognizer on android. It uses [Vosk](https://github.com/alphacep/vosk-api) with custom model.

## Model Extractor

A speech model extractor to build custom dictionary for the recognizer.

### Setup

- Install flutter sdk and [setup desktop environment](https://docs.flutter.dev/desktop).
- Run `git lfs pull` command.
- Run this project in MacOS.
- Enter the words that need to build dictionary into text box.
- The result model is in `output/model-id-id`.
- Copy & replace `output/model-id-id/graph` into application `speech_recognizer/android/models/src/main/assets/model-id-id/graph`.

## Contributors

<a href="https://github.com/bookbot-kids//graphs/contributors">
  <img src="https://contrib.rocks/image?repo=bookbot-kids/speech-recognizer-bahasa-indonesian" />
</a>
