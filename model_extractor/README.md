# Model Extractor

A speech model extractor to build custom dictionary for the recognizer.

## Setup

- Install flutter sdk and [setup desktop environment](https://docs.flutter.dev/desktop).
- Run `git lfs pull` command.
- Run this project in MacOS.
- Enter the words that need to build dictionary into text box.
- The result model is in `output/model-id-id`.
- Copy & replace `output/model-id-id/graph` into application `speech_recognizer/android/models/src/main/assets/model-id-id/graph`.
