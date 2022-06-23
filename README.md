# Speech Recognizer Bahasa Indonesia

A cross platform (Android/iOS/MacOS) Bahasa Indonesia speech recognizer library, written in Flutter. The speech recognizer library reads a buffer from a microphone device and converts spoken words into text in near-instant inference time with high accuracy. This library is also extensible to your own custom speech recognition model!

## Features

- Indonesian speech-to-text through an automatic speech recognition (ASR) model.
- Train custom machine learning model with [model extractor](https://github.com/bookbot-kids/speech-recognizer-bahasa-indonesian/tree/main/model_extractor).
- Integrate speech-to-text model with mobile and desktop applications.

## Installation / Setup

- Install [Flutter SDK](https://docs.flutter.dev/get-started/install).
- Run `git lfs pull` command.
- Install [Visual Studio Code](https://code.visualstudio.com/).
- Open the project in Visual Studio Code, navigate to `lib/main.dart`.
- Launch an Android emulator or iOS simulator. Optionaly, you can also connect to a real device.
- Run the demo on Android/iOS/MacOS by going to the top navigation bar of VSCode, hit **Run**, then **Start Debugging**.

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
- Add microphone permission `nsmicrophoneusagedescription`. You can follow this [guide](https://stackoverflow.com/a/38498347/719212).

## How to Use

### Flutter Sample App

- After setting up, run the app by pressing the `Start listening` button.
- Speak into the microphone and the corresponding output text will be displayed in the text field.
- Press `Stop listening` to stop the app from listening.

<details>
  <summary>Code</summary>

```dart
import 'package:speech_recognizer/speech_recognizer.dart';

// setup listener by implements SpeechListener in your class
class _MyHomePageState implements SpeechListener {
  final recognizer = SpeechController.shared;

  Future<void> _setup() async {
    // ask for recording permission
    final permissions = await recognizer.permissions();
    if (permissions == AudioSpeechPermission.undetermined) {
      await recognizer.authorize();
    }

    if (await recognizer.permissions() != AudioSpeechPermission.authorized) {
      return;
    }

    // initialize recognizer model with indonesian langauge
    await recognizer.initSpeech('id');
    // register listener in this class
    recognizer.addListener(this);

    // start to listen voice on microphone
    recognizer.listen();
  }

  /// This is the output text listener while speaking
  @override
  void onResult(Map result, bool wasEndpoint) {
    // normalized result
    List<List<String>> candidates = result.containsKey('partial')
        ? [result['partial'].trim().split(' ')]
        : result['alternatives']
            .map((x) => x['text'].trim().split(' ').cast<String>().toList())
            .toList()
            .cast<List<String>>();
    // print recognized words
    print(candidates);
  }
}
```

</details>

<!-- TODO: add other platforms -->

## File Structure

| Platform      | Code                                                                                                                                                                                                   | Function                                                                                                                                                      |
| ------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Flutter       | [`speech_recognizer.dart`](https://github.com/bookbot-kids/speech-recognizer-bahasa-indonesian/blob/main/speech_recognizer/lib/speech_recognizer.dart)                                                 | Interface API to communicate with native platform (Android/iOS/Mac). There are many speech recognizer methods, check `lib/main.dart` to know how to use them. |
| All Platforms | [`model-id-id`](https://github.com/bookbot-kids/speech-recognizer-bahasa-indonesian/tree/main/speech_recognizer/android/models/src/main/assets/model-id-id)                                            | Speech model shared for all platforms. Replace `model-id-id/graph` to change the model dictionary.                                                            |
| iOS/MacOS     | [`SpeechController.swift`](https://github.com/bookbot-kids/speech-recognizer-bahasa-indonesian/blob/main/speech_recognizer/swift/SpeechController.swift)                                               | Native platform channel for speech recognizer on iOS/MacOS. It uses [Vosk](https://github.com/alphacep/vosk-api) with custom model.                           |
| Android       | [`SpeechController.kt`](https://github.com/bookbot-kids/speech-recognizer-bahasa-indonesian/blob/main/speech_recognizer/android/app/src/main/kotlin/com/bookbot/speech_recognizer/SpeechController.kt) | Native platform channel for speech recognizer on android. It uses [Vosk](https://github.com/alphacep/vosk-api) with custom model.                             |

## Helpful Links & Resources

- [Flutter developer document](https://docs.flutter.dev/)
- [Android developer document](https://developer.android.com/docs)
- [iOS/MacOS developer document](https://developer.apple.com/documentation/)

## Contributors

<a href="https://github.com/bookbot-kids//graphs/contributors">
  <img src="https://contrib.rocks/image?repo=bookbot-kids/speech-recognizer-bahasa-indonesian" />
</a>
