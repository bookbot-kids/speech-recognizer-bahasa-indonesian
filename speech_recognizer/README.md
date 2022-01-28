# speech_recognizer

The Bahasa Indonesian speech recognizer flutter app. 
It will read buffer from microphone and recognize speaking words

# setup
- Install flutter sdk
- Run `git lfs pull` command
- Run the demo on android/ios/macos

# structure
- `lib/speech_recognizer.dart`: this is the interface API to communicate with native platform (android/ios/mac). There are many speech recognizer methods, check `lib/main.dart` to know how to use them.
- `android/models/src/main/assets/model-id-id`: this is the speech model that shared for all platforms. Replace `model-id-id/graph` to change the model dictionary.
- `swift/SpeechController.swift`: the native platform channel for speech recognizer on ios/macos. It uses (vosk)[https://github.com/alphacep/vosk-api] with custom model
- `android/app/src/main/kotlin/com/bookbot/speech_recognizer/SpeechController.kt`: the native platform channel for speech recognizer on android. It uses (vosk)[https://github.com/alphacep/vosk-api] with custom model