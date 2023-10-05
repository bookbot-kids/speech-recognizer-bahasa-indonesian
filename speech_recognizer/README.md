# Speech Recognizer

An Indonesian children's speech recognizer Flutter app for Android/iOS/MacOS. It will read buffer from microphone and recognize speaking words.

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
- Add microphone permission `NSMicrophoneUsageDescription`. You can follow this [guide](https://stackoverflow.com/a/38498347/719212).

### Testing
- Follow the same Installation / Setup guide
- Launch an Android emulator or iOS simulator
- Run `flutter test integration_test/app_test.dart` 