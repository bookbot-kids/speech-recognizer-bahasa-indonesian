# Model Extractor

A speech model extractor to build custom ML model dictionary for the recognizer.

## Installation / Setup​

- Install [flutter sdk](https://docs.flutter.dev/get-started/install) and [setup desktop environment](https://docs.flutter.dev/desktop).
- Run `git lfs pull` command.
- Run this project in MacOS.
- Enter the words (split by `,`) that need to build ML model dictionary into text box.
- The result model is in `output/model-id-id`.
- Copy & replace `output/model-id-id/graph` into application `speech_recognizer/android/models/src/main/assets/model-id-id/graph` then run `speech_recognizer` project
