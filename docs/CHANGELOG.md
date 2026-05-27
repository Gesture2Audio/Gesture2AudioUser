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

## 2026-05-11 - Replace Demo Matcher With Trained Bird/River Model

- Changed: Replaced the phone-side nearest-neighbor demo matcher with a trained logistic-regression model bundled as `bird_river_model.json`. Added a reproducible training script and switched the phone pipeline to transient classification by default, with optional research save mode.
- Reason: The user app should use a real trained model rather than compare incoming captures against raw stored training examples, and the default phone behavior should focus on classification and audio layering instead of always behaving like a collector app.
- Files: `scripts/train_bird_river_model.py`, `iPhone App/Gesture2AudioUser/Gesture2AudioUser/bird_river_model.json`, `iPhone App/Gesture2AudioUser/Gesture2AudioUser/GesturePipeline.swift`, `iPhone App/Gesture2AudioUser/Gesture2AudioUser/PhoneDebugSession.swift`, `iPhone App/Gesture2AudioUser/Gesture2AudioUser/ContentView.swift`, `docs/IPHONE_PIPELINE.md`, `README.md`, `docs/CHANGELOG.md`.
- Validation: Trained the model from `data/training_samples_full.json`. Result: 0.923 five-fold CV accuracy, 1.000 held-out accuracy, confusion matrix `[[11, 0], [0, 12]]`. Participant-held-out validation remained weak at 0.525 and 0.490, so the current model is suitable for the controlled bird/fish demo but not yet for broad user generalization.
- Notes: The active app now loads the trained model artifact from `Bundle.main`. The default phone flow is `receive capture -> classify immediately -> layer audio -> discard raw capture`, unless research save mode is turned on in the UI.

## 2026-05-12 - Move Bird/River Audio Processing Into Embedded HTML Engine

- Changed: Replaced the native Swift bird/river sound engine with an embedded `WKWebView` soundscape engine driven by local HTML and JavaScript. Added native mood buttons for `happy`, `neutral`, and `sad`, while keeping gesture classification on the phone. The app now sends classified gestures and selected mood to the embedded HTML engine.
- Reason: The iPhone app needed to align its sound-characteristics behavior with the existing HTML prototype instead of maintaining a separate native DSP path.
- Files: `iPhone App/Gesture2AudioUser/Gesture2AudioUser/SoundscapeWebController.swift`, `iPhone App/Gesture2AudioUser/Gesture2AudioUser/soundscape_embed.html`, `iPhone App/Gesture2AudioUser/Gesture2AudioUser/PhoneDebugSession.swift`, `iPhone App/Gesture2AudioUser/Gesture2AudioUser/ContentView.swift`, `iPhone App/Gesture2AudioUser/Gesture2AudioUser/GesturePipeline.swift`, `docs/CHANGELOG.md`, `docs/IPHONE_PIPELINE.md`.
- Validation: Matched the HTML prototype behavior for two sources (`birds`, `river`), mood-dependent filter chains, mood-dependent playback-rate changes, additive layering, reset behavior, and waveform/status display through the embedded page bridge.
- Notes: The embedded HTML uses procedural bird and river sources so the app keeps the same demo sounds as the previous native implementation without needing external `.wav` assets.

## 2026-05-12 - Switch Embedded HTML Engine To Bundled WAV Assets

- Changed: Replaced the embedded HTML engine's procedural bird and river sources with bundled `birds.wav` and `river.wav` assets copied from the `G2A_Soundscape` repository.
- Reason: The app should now use the same audio files as the soundscape prototype while keeping the same embedded HTML control path.
- Files: `iPhone App/Gesture2AudioUser/Gesture2AudioUser/audio/birds.wav`, `iPhone App/Gesture2AudioUser/Gesture2AudioUser/audio/river.wav`, `iPhone App/Gesture2AudioUser/Gesture2AudioUser/soundscape_embed.html`, `docs/CHANGELOG.md`, `docs/IPHONE_PIPELINE.md`.
- Validation: Confirmed both WAV files are present in the active iPhone app folder and updated the embedded HTML engine to fetch `audio/birds.wav` and `audio/river.wav` locally from the app bundle.
- Notes: Gesture classification and native mood controls are unchanged. Only the audio source backing changed from generated signals to file-backed loops.

## 2026-05-12 - Fix HTML Preview Cropping And File-Backed Audio Bridge

- Changed: Increased the embedded HTML preview height so the full soundscape panel is visible, injected explicit bundle file URLs for `birds.wav` and `river.wav` into the `WKWebView` page, and added bridge-level error reporting plus audio priming.
- Reason: After pulling the latest repo state, the HTML preview was visually cropped and gesture-triggered playback was failing silently, leaving the app stuck on `No sources active` even after successful classification.
- Files: `iPhone App/Gesture2AudioUser/Gesture2AudioUser/ContentView.swift`, `iPhone App/Gesture2AudioUser/Gesture2AudioUser/SoundscapeWebController.swift`, `iPhone App/Gesture2AudioUser/Gesture2AudioUser/soundscape_embed.html`, `docs/CHANGELOG.md`.
- Validation: Confirmed the preview card now reserves enough vertical space for the full HTML panel. Updated the HTML engine to load audio from explicit bundle URLs and surface load/init failures back to Swift, which can now display the exact error in the app instead of silently showing no active layers.
- Notes: The pulled remote update was `d0dae22 initializer values fixed`, which only changed a single initializer value and did not affect the cropped preview or audio-loading path.

## 2026-05-22 - Clean May 21 Multi-Participant Dataset

- Changed: Added a reproducible cleaning pass for `New_ML/IMU2IMG-2/New Data`, plus three new dataset artifacts: a compact cleaned manifest, a full cleaned training JSON with embedded frames, and a cleaning report that records dropped samples.
- Reason: The new collection contains five participant folders and needs the same kind of training-data cleanup that was done for the earlier dataset before it can be used safely for model work.
- Files: `scripts/clean_new_data.py`, `data/new_data_valid_samples.json`, `data/new_data_training_full.json`, `data/new_data_cleaning_report.json`, `README.md`, `docs/CHANGELOG.md`.
- Validation: Scanned all 847 JSON files, confirmed one consistent schema, 3-second duration, and 50 Hz sampling throughout. Kept 844 samples and dropped 3 shortened tree captures below 140 frames. Final kept counts: `bird 148`, `leaf 133`, `ocean 141`, `rain 143`, `river 146`, `tree 133`.
- Notes: The three dropped files were `20260521_133252_day_01_tree_D7943879.json` (Cerella, 122 frames), `20260521_174122_day_01_tree_BA99C760.json` (Hong, 131 frames), and `20260521_115436_day_01_tree_EA8A9BDE.json` (Rakesh, 108 frames). Everything else was inside the normal timing band and kept.

## 2026-05-22 - Build Combined 7-Participant Training File

- Changed: Added one merged training JSON under `data/New training set` that combines the original cleaned 2-participant dataset with the cleaned May 21 5-participant dataset into a single normalized schema.
- Reason: Model training now needs one consolidated source file instead of separate old and new cleaned datasets.
- Files: `scripts/build_combined_training_set.py`, `data/New training set/combined_training_samples_full.json`, `README.md`, `docs/CHANGELOG.md`.
- Validation: Combined `277` original samples with `844` new cleaned samples into `1121` total valid samples across `7` participants and `169,135` IMU frames. Final merged label counts: `leaf 178`, `tree 182`, `bird 192`, `ocean 183`, `river 193`, `rain 193`.
- Notes: The merged file normalizes both source datasets into one common sample schema with `dataset_source`, `sample_id`, participant metadata, label metadata, and embedded IMU frames.

## 2026-05-25 - Add Six-Gesture Cleaning And Baseline Training

- Changed: Added a reproducible six-gesture cleanup and model-evaluation script, generated a stricter cleaned v2 training set, saved a metrics report, and trained a sklearn PCA/logistic-regression model artifact.
- Reason: The current goal is to improve the predefined six-gesture model without collecting more participant data.
- Files: `scripts/clean_and_train_six_gestures.py`, `data/cleaned_training_v2/cleaned_training_samples_full.json`, `outputs/six_gesture_cleaning_report.json`, `models/six_gesture_logreg_pca_model.pkl`, `README.md`, `docs/CHANGELOG.md`.
- Validation: Started from `1121` combined samples and kept `940` after motion-quality and class-outlier filtering. The best random-holdout baseline reached `0.840` with ExtraTrees on the cleaned set. The best participant-held-out result improved from `0.457` to `0.480` with PCA/logistic regression.
- Notes: Cleaning helps, but the participant-held-out result is still not strong enough for a robust new-user claim. The remaining gap is mainly participant drawing-style variation rather than simple corrupt files.

## 2026-05-25 - Train Final Six-Gesture Model

- Changed: Added a final six-gesture trainer that compares PCA/logistic regression, linear SVC, RBF SVC, ridge classifier, ExtraTrees, and random forest, then saves the model selected by participant-held-out macro F1.
- Reason: The project needs a trained six-class model with full metrics, not only a cleaning report.
- Files: `scripts/train_six_gesture_model.py`, `outputs/six_gesture_model_report.json`, `models/six_gesture_final_model.pkl`, `README.md`, `docs/CHANGELOG.md`.
- Validation: Trained on `data/cleaned_training_v2/cleaned_training_samples_full.json` with `940` samples and `652` engineered features. Selected `pca_logistic_regression`. Random holdout: accuracy `0.723`, macro F1 `0.724`, weighted F1 `0.724`. Leave-one-participant-out: accuracy `0.480`, macro F1 `0.478`, weighted F1 `0.479`.
- Notes: ExtraTrees had the strongest random-holdout result at accuracy `0.846` and macro F1 `0.847`, but it generalized worse to unseen participants with leave-one-participant-out macro F1 `0.391`.

## 2026-05-25 - Add Six-Gesture Training Notebook

- Changed: Added a visual-first Jupyter notebook version of the six-gesture model training flow with cells for loading data, feature extraction, model comparison, F1 reporting, participant-held-out evaluation, confusion matrices, normalized confusion matrices, metric heatmaps, model/report saving, and final combined dashboards.
- Reason: The model training should be reviewable and runnable as a notebook rather than only as a Python script.
- Files: `notebooks/six_gesture_model_training.ipynb`, `README.md`, `docs/CHANGELOG.md`.
- Validation: Parsed all code cells successfully as Python and verified the notebook contains the visual-first sections on disk: dataset distribution charts, model comparison charts, selected-model visual analysis, confusion matrix plots, held-out participant plot, and the final combined dashboard.
- Notes: The notebook keeps the same selected-model logic as `scripts/train_six_gesture_model.py`: choose the model with the best leave-one-participant-out macro F1. The final visual summary plots model comparison, selected-model overall metrics, class precision/recall/F1, held-out participant scores, raw confusion, and normalized confusion together.
- Fix: Moved the plotting helper cell near the top of the notebook so chart cells can run in order without `NameError: style_axes is not defined`.

## 2026-05-27 - Improve Six-Gesture LOPO Demo Model

- Changed: Added a `SelectKBest` feature-selection logistic-regression candidate to the six-gesture training flow, regenerated the final model artifact, and aligned the notebook with the selected model.
- Reason: The next supervisor demo needs the strongest honest six-gesture result from the current dataset, with the LOPO confusion matrix as the main evidence.
- Files: `scripts/train_six_gesture_model.py`, `notebooks/six_gesture_model_training.ipynb`, `outputs/six_gesture_model_report.json`, `models/six_gesture_final_model.pkl`, `README.md`, `docs/CHANGELOG.md`.
- Validation: Re-ran six-gesture training on `data/cleaned_training_v2/cleaned_training_samples_full.json`. Selected model: `kbest200_logistic_regression`. Random holdout: `0.851` accuracy and `0.852` macro F1. LOPO: `0.520` accuracy and `0.522` macro F1.
- Notes: The model is better for the demo than the earlier PCA/logistic baseline, but LOPO still shows user-style drift. Rain and tree are the strongest classes; leaf, bird, river, and ocean still share several confusions.

## 2026-05-27 - Integrate Six-Gesture Model Into iPhone App

- Changed: Exported the selected six-gesture sklearn pipeline to an iPhone-readable JSON artifact, replaced the app's old bird/fish classifier with six-class on-device inference, updated the UI for all six gestures, and extended the embedded HTML engine to activate six audio layers.
- Reason: The user app needs to demonstrate the full predefined six-gesture pipeline, not only the earlier bird/fish prototype.
- Files: `scripts/export_six_gesture_ios_model.py`, `iPhone App/Gesture2AudioUser/Gesture2AudioUser/six_gesture_model.json`, `iPhone App/Gesture2AudioUser/Gesture2AudioUser/GesturePipeline.swift`, `iPhone App/Gesture2AudioUser/Gesture2AudioUser/ContentView.swift`, `iPhone App/Gesture2AudioUser/Gesture2AudioUser/SoundscapeWebController.swift`, `iPhone App/Gesture2AudioUser/Gesture2AudioUser/soundscape_embed.html`, `docs/IPHONE_PIPELINE.md`, `README.md`, `docs/CHANGELOG.md`.
- Validation: Verified the exported JSON has `652` scaler features, `200` selected feature indices, six coefficient rows, and six intercepts. Recomputed predictions from the exported JSON in Python and confirmed they match the sklearn pipeline for sampled records.
- Notes: Bird and river still use the bundled WAV assets. Leaf, tree, ocean, and rain use generated HTML-engine layers for the demo until final sound files are added.

## 2026-05-27 - Replace App Soundscape With G2A Soundscape Generator

- Changed: Pulled the latest `Gesture2Audio/G2A_Soundscape` repo and replaced the app's embedded soundscape page with the new `soundscape-generator` HTML, sample metadata, and bundled audio pool files. Updated the Swift bridge so gesture labels activate the generator's source IDs.
- Reason: The app should use the newer sound profiles and soundscape behavior from the dedicated soundscape repo instead of the earlier custom two-source embed.
- Files: `iPhone App/Gesture2AudioUser/Gesture2AudioUser/soundscape_embed.html`, `iPhone App/Gesture2AudioUser/Gesture2AudioUser/data/sample-library.json`, `iPhone App/Gesture2AudioUser/Gesture2AudioUser/data/sources.json`, `iPhone App/Gesture2AudioUser/Gesture2AudioUser/audio/pools/leaf/*.mp3`, `iPhone App/Gesture2AudioUser/Gesture2AudioUser/SoundscapeWebController.swift`, `iPhone App/Gesture2AudioUser/Gesture2AudioUser/ContentView.swift`, `README.md`, `docs/IPHONE_PIPELINE.md`, `docs/CHANGELOG.md`.
- Validation: Confirmed the copied soundscape metadata contains six categories with 50 samples each and added native bridge functions for `primeAudio`, `setMood`, `ensureSound`, `toggleSound`, and `reset`.
- Notes: Native labels still remain `leaf`, `tree`, `bird`, `ocean`, `river`, and `rain`; the bridge maps them to the generator IDs `leaf`, `tree`, `bird`, `wave`, `fish`, and `cloud`.
