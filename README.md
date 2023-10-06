# Home

## Children's Speech Recognizer Bahasa Indonesia

<p align="center">
    <a href="https://github.com/bookbot-kids/speech-recognizer-bahasa-indonesian/blob/main/LICENSE.md">
        <img alt="GitHub" src="https://img.shields.io/github/license/bookbot-kids/speech-recognizer-bahasa-indonesian.svg?color=blue">
    </a>
    <a href="https://bookbot-kids.github.io/speech-recognizer-bahasa-indonesian/">
        <img alt="Documentation" src="https://img.shields.io/website/http/bookbot-kids.github.io/speech-recognizer-bahasa-indonesian.svg?down_color=red&down_message=offline&up_message=online">
    </a>
    <a href="https://github.com/bookbot-kids/speech-recognizer-bahasa-indonesian/blob/main/CODE_OF_CONDUCT.md">
        <img alt="Contributor Covenant" src="https://img.shields.io/badge/Contributor%20Covenant-v2.0%20adopted-ff69b4.svg">
    </a>
    <a href="https://discord.gg/gqwTPyPxa6">
        <img alt="chat on Discord" src="https://img.shields.io/discord/1001447685645148169?logo=discord">
    </a>
    <a href="https://github.com/bookbot-kids/speech-recognizer-bahasa-indonesian/blob/main/CONTRIBUTING.md">
        <img alt="contributing guidelines" src="https://img.shields.io/badge/contributing-guidelines-brightgreen">
    </a>
</p>

A cross platform (Android/iOS/MacOS) Bahasa Indonesia children's speech recognizer library, written in Flutter and leveraging the Kaldi framework. The speech recognizer library reads a buffer from a microphone device and converts spoken words into text in near-instant inference time with high accuracy. This library is also extensible to your own custom speech recognition model!

!!! note

    Since our built-in default model was trained on children's speech, it may perform poorly on adult's speech.

## Features

- Indonesian speech-to-text through a Kaldi-based automatic speech recognition (ASR) model, trained on children's speech.
- Train custom machine learning model with [model extractor](https://github.com/bookbot-kids/speech-recognizer-bahasa-indonesian/tree/main/model_extractor).
- Integrate speech-to-text model with mobile and desktop applications.

## Installation / Setup

- Install [Flutter SDK](https://docs.flutter.dev/get-started/install).
- Run `git lfs pull` command.
- Install [Visual Studio Code](https://code.visualstudio.com/).
- Open the project in Visual Studio Code, navigate to `lib/main.dart`.
- Launch an Android emulator or iOS simulator. Optionaly, you can also connect to a real device.
- Run the demo on Android/iOS/MacOS by going to the top navigation bar of VSCode, hit **Run**, then **Start Debugging**.

Note Kaldi libraries have been compiled from commit hash `9af2c5c16389e141f527ebde7ee432a0c1df9fb9` with OpenFST v1.7.3.

### Android

On Android, you will need to allow microphone permission in `AndroidManifest.xml` like so:

```xml
<uses-feature android:name="android.hardware.microphone" android:required="false"/>
<uses-permission android:name="android.permission.RECORD_AUDIO"/>
```

### iOS

Similarly on iOS/MacOS:

- Open Xcode
- Navigate to `Info.plist`
- Add microphone permission `NSMicrophoneUsageDescription`. You can follow this [guide](https://stackoverflow.com/a/38498347/719212).

## How to Use

### Flutter Sample App

- After setting up, run the app by pressing the `Load model` button and then `Start listening`
- Speak into the microphone and the corresponding output text will be displayed in the text field.
- Press `Stop listening` to stop the app from listening.

```dart title="main.dart"
import 'package:speech_recognizer/speech_recognizer.dart';

class _MyHomePageState implements SpeechListener { // (1)
  final recognizer = SpeechController.shared;

  void _load() async {
    // ask for permission
    final permissions = await SpeechController.shared.permissions(); // (2)
    if (permissions == AudioSpeechPermission.undetermined) {
      await SpeechController.shared.authorize();
    }

    if (await SpeechController.shared.permissions() !=
        AudioSpeechPermission.authorized) {
      return;
    }

    if (!_isInitialized) {
      await SpeechController.shared.initSpeech('id'); // (3)
      setState(() {
        _isInitialized = true;
      });

      SpeechController.shared.addListener(this); // (4)
    }
  }

  @override
  void onResult(Map result, bool wasEndpoint) { // (5)
    List<List<String>> candidates = result.containsKey('partial') // (6)
        ? [result['partial'].trim().split(' ')]
        : result['alternatives']
            .map((x) => x['text'].trim().split(' ').cast<String>().toList())
            .toList()
            .cast<List<String>>();
    if (candidates.isEmpty ||
        !candidates
            .any((element) => element.any((element) => element.isNotEmpty))) {
      return;
    }
  }
}
```

1. Setup listener by implements `SpeechListener` in your class.
2. Ask for recording permission.
3. Initialize Indonesian recognizer model.
4. Register listener in this class.
5. Output text listener while speaking.
6. Normalized result.

<!-- TODO: add other platforms -->

## File Structure

| Platform      | Code                                                                                                                                                                                                   | Function                                                                                                                                                      |
| ------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Flutter       | [`speech_recognizer.dart`](https://github.com/bookbot-kids/speech-recognizer-bahasa-indonesian/blob/main/speech_recognizer/lib/speech_recognizer.dart)                                                 | Interface API to communicate with native platform (Android/iOS/Mac). There are many speech recognizer methods, check `lib/main.dart` to know how to use them. |
| All Platforms | [`model-id-id`](https://github.com/bookbot-kids/speech-recognizer-bahasa-indonesian/tree/main/speech_recognizer/android/models/src/main/assets/model-id-id)                                            | Speech model shared for all platforms. Replace `model-id-id/graph` to change the model dictionary.                                                            |
| iOS/MacOS     | [`SpeechController.swift`](https://github.com/bookbot-kids/speech-recognizer-bahasa-indonesian/blob/main/speech_recognizer/swift/SpeechController.swift)                                               | Native platform channel for speech recognizer on iOS/MacOS. It uses [Vosk](https://github.com/alphacep/vosk-api) with custom model.                           |
| Android       | [`SpeechController.kt`](https://github.com/bookbot-kids/speech-recognizer-bahasa-indonesian/blob/main/speech_recognizer/android/app/src/main/kotlin/com/bookbot/speech_recognizer/SpeechController.kt) | Native platform channel for speech recognizer on android. It uses [Vosk](https://github.com/alphacep/vosk-api) with custom model.                             |

## UI Automation Testing
- Follow [Installation / Setup](#installation--setup) guide
- Launch an Android emulator or iOS simulator
- Run `flutter test integration_test/app_test.dart`  

https://github.com/bookbot-kids/speech-recognizer-bahasa-indonesian/assets/5583266/5fe9c78b-ffa0-45b7-9421-23bf2302f6e5

## Helpful Links & Resources

- [Flutter developer document](https://docs.flutter.dev/)
- [Android developer document](https://developer.android.com/docs)
- [iOS/MacOS developer document](https://developer.apple.com/documentation/)

## Contributors

<a href="https://github.com/bookbot-kids/speech-recognizer-bahasa-indonesian/graphs/contributors">
  <img src="https://contrib.rocks/image?repo=bookbot-kids/speech-recognizer-bahasa-indonesian" />
</a>

## Credits

[Alpha Cephei/Vosk](https://github.com/alphacep/vosk-api)
