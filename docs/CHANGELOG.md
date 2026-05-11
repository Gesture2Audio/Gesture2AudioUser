# Change Log

All notable project changes should be documented here. Add a new entry whenever code, data processing, model behavior, architecture, or research assumptions change.

Format:

```text
## YYYY-MM-DD - Short Title

- Changed:
- Reason:
- Files:
- Validation:
- Notes:
```

## 2026-05-11 - Initial Research Documentation

- Changed: Added project documentation, version-control workflow, and decision log.
- Reason: The project will continue over multiple chats and needs persistent documentation for every change.
- Files: `README.md`, `docs/PROJECT_BRIEF.md`, `docs/CHANGELOG.md`, `docs/DECISIONS.md`, `docs/VERSION_CONTROL.md`, `.gitignore`.
- Validation: Checked workspace structure and sampled raw JSON data layout.
- Notes: Workspace was not a Git repository before this documentation pass. GitHub remote selected: `https://github.com/Gesture2Audio/Gesture2AudioUser.git`.

## 2026-05-11 - Add Valid Training Manifest

- Changed: Added `data/valid_samples.json` with the approved 277 training samples selected from the current `20260505_*.json` recording sequence. Added `data/training_samples_full.json` with the same approved samples and embedded IMU frame values.
- Reason: The raw data folder contains 383 current recordings, but only the manually approved index ranges should be used for model training.
- Files: `data/valid_samples.json`, `data/training_samples_full.json`, `README.md`, `docs/PROJECT_BRIEF.md`, `docs/CHANGELOG.md`, `.gitignore`.
- Validation: Generated the manifest from `G2A_Raw_Data/G2A`, checked each selected file's filename label and JSON `label` against the expected range label, and confirmed per-label counts. Generated the full training JSON from the manifest and confirmed 277 samples and 41,787 frames.
- Notes: The valid manifest uses 1-based filename order over `20260505_*.json`; older app-installation files in `GesturetoAudio` are not part of the training set. The JSON is formatted with standard two-space indentation and consistent snake_case field names.

## 2026-05-11 - Add Binary Gesture Demo

- Changed: Added a small two-gesture classification notebook and demo notes for showing the pipeline.
- Reason: The supervisor demo only needs to show that two gestures, such as bird and fish, can be separated from the cleaned IMU data.
- Files: `notebooks/binary_gesture_demo.ipynb`, `docs/DEMO_PIPELINE.md`, `README.md`, `docs/CHANGELOG.md`.
- Validation: Converted the first model try from a command-line script into a notebook with separate cells for loading data, filtering gestures, feature extraction, training, evaluation, and the audio-layer explanation.
- Notes: The user-facing `fish` gesture maps to the model label `river`.

## 2026-05-11 - Add iPhone Bird/Fish Pipeline

- Changed: Added an iPhone/watch Xcode project for the first live bird/fish pipeline. The iPhone receives watch IMU captures, classifies bird vs fish/river, and layers procedural bird/river audio.
- Reason: The supervisor demo needs the flow where bird starts bird audio, then fish adds river audio on top, and the reverse order also works.
- Files: `iphone_app/GesturetoAudioPipeline`, `docs/IPHONE_PIPELINE.md`, `README.md`, `docs/CHANGELOG.md`, `.gitignore`.
- Validation: Created `bird_river_training.json` from approved samples and ran a Python mirror of the iPhone nearest-neighbor classifier. Result: 0.901 five-fold CV accuracy and 0.913 held-out accuracy.
- Notes: The app classifies after each 3-second watch capture arrives on the phone. This is the first testable live pipeline, not the final continuous Core ML classifier. The copied reference project was adjusted to use neutral bundle IDs, no hard-coded Apple team, and a watch motion usage description.

## 2026-05-11 - Fix Gesture Decode Build Error

- Changed: Switched the gesture decode models in the active iPhone app target from `Codable` to `Decodable` and marked them `Sendable`.
- Reason: The build was failing because `IMUFrame` used decode-only coding keys, which broke synthesized `Encodable`, and Swift 6 concurrency was complaining at the JSON decode site.
- Files: `iPhone App/Gesture2AudioUser/Gesture2AudioUser/GesturePipeline.swift`, `docs/CHANGELOG.md`.
- Validation: Reviewed the active app target referenced by the user and checked that only the decode-path types were involved in `JSONDecoder().decode(...)`.
- Notes: This keeps the flexible snake_case/camelCase JSON decoding logic without requiring an unused custom encoder.

## 2026-05-11 - Fix Missing Bundled Model In Active App

- Changed: Added `bird_river_training.json` to the active iPhone app target folder and improved classifier load-status reporting in the UI.
- Reason: The app was always showing `model unavailable` because the active `Gesture2AudioUser` target did not include the bundled training JSON that the classifier tries to load from `Bundle.main`.
- Files: `iPhone App/Gesture2AudioUser/Gesture2AudioUser/bird_river_training.json`, `iPhone App/Gesture2AudioUser/Gesture2AudioUser/GesturePipeline.swift`, `iPhone App/Gesture2AudioUser/Gesture2AudioUser/PhoneDebugSession.swift`, `docs/CHANGELOG.md`.
- Validation: Regenerated the bird/river training JSON from `data/training_samples_full.json` and verified the file was created in the active app target folder with 91 samples.
- Notes: If the file is missing from the built app bundle again, the status text now reports that exact failure instead of a generic unavailable message.
