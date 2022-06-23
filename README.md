# Speech Recognizer Bahasa Indonesia

- A cross platform (Android/iOS/MacOS) Bahasa Indonesian speech recognizer library, written in Flutter
- This library can read buffer from device microphone and recognize spoken words into text.
- The library process is very fast, and it's quite accuracy, you can train your own machine learning model.

## Usage
```
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
      eturn;
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
- After setup, run the app and press `Start listening` button to listen speech and get the spoken output text in text field.
- Press `Stop listening` to stop listening
  
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
## Features
​
- Ask user for microphone permission to recognize voice.
- Convert microphone audio buffer into text by using Machine learning model and display in UI.
- Training custom Machine learning model for more accuracy with [model extractor ](https://github.com/bookbot-kids/speech-recognizer-bahasa-indonesian/tree/main/model_extractor)
- User can start/stop speech recognizer.
​
## References
​
### Learn More
​
- [Flutter developer document](https://docs.flutter.dev/)
- [android developer document](https://developer.android.com/docs)
- [iOS/macOS developer document](https://developer.apple.com/documentation/)
​
### Citation
​
- None