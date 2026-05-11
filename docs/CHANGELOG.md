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

- Changed: Added a small two-gesture classification script and demo notes for showing the pipeline.
- Reason: The supervisor demo only needs to show that two gestures, such as bird and fish, can be separated from the cleaned IMU data.
- Files: `scripts/binary_gesture_demo.py`, `docs/DEMO_PIPELINE.md`, `README.md`, `docs/CHANGELOG.md`.
- Validation: Ran the demo script on bird vs fish/river after feature tuning and checked cross-validation plus held-out results.
- Notes: The user-facing `fish` gesture maps to the model label `river`.
