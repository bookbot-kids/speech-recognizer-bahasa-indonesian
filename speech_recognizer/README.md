# Speech Recognizer

An Indonesian speech recognizer Flutter app for Android/iOS/MacOS. It will read buffer from microphone and recognize speaking words.

## Installation / Setup
​
- Install [flutter sdk](https://docs.flutter.dev/get-started/install) base on each platform
- Run `git lfs pull` command.
- Install (visual studio code)[https://code.visualstudio.com/]
- Open project in visual studio code, navigate to `lib/main.dart`
- Launch android emulator or ios simulator or connect to real device.
- Run the demo on Android/iOS/MacOS by menu Run -> Start debugging in visual studio code.
- On android: Need to declare microphone permission in `AndroidManifest.xml`
    ```
    <uses-feature android:name="android.hardware.microphone" android:required="false"/>
    <uses-permission android:name="android.permission.RECORD_AUDIO"/>
    ```
- On iOS/macOS: go to xcode -> Info.plist -> add microphone permission `nsmicrophoneusagedescription` like this https://stackoverflow.com/a/38498347/719212

## Project Structure

- [`lib/speech_recognizer.dart`](lib/speech_recognizer.dart)
  - This is the interface API to communicate with native platform (android/iOS/Mac). There are many speech recognizer methods, check [`lib/main.dart`](lib/main.dart) to know how to use them.
- [`android/models/src/main/assets/model-id-id`](android/models/src/main/assets/model-id-id/)
  - This is the speech model that shared for all platforms. Replace `model-id-id/graph` to change the model dictionary.
- [`swift/SpeechController.swift`](swift/SpeechController.swift)
  - The native platform channel for speech recognizer on iOS/MacOS. It uses [Vosk](https://github.com/alphacep/vosk-api) with custom model.
- [`android/app/src/main/kotlin/com/bookbot/speech_recognizer/SpeechController.kt`](android/app/src/main/kotlin/com/bookbot/speech_recognizer/SpeechController.kt)
  - The native platform channel for speech recognizer on android. It uses [Vosk](https://github.com/alphacep/vosk-api) with custom model.

- View [full documentation](https://github.com/bookbot-kids/speech-recognizer-bahasa-indonesian/tree/main/speech_recognizer/doc/api/index.html)