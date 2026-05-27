# G2A Research Prototype

This workspace documents and develops the G2A research prototype: an Apple Watch IMU-based mid-air gesture system for composing layered nature soundscapes that adapt gradually to the user's physiological state.

Start here:

- [Project brief](docs/PROJECT_BRIEF.md)
- [Demo pipeline](docs/DEMO_PIPELINE.md)
- [iPhone pipeline](docs/IPHONE_PIPELINE.md)
- [Change log](docs/CHANGELOG.md)
- [Decision log](docs/DECISIONS.md)
- [Version-control workflow](docs/VERSION_CONTROL.md)

Current raw gesture data is stored in `G2A_Raw_Data/G2A`.

Training data files:

- `data/valid_samples.json`: compact manifest with approved samples and source file paths.
- `data/training_samples_full.json`: single self-contained JSON with the approved samples and embedded IMU frame values.
- `data/new_data_valid_samples.json`: cleaned manifest for the May 21 multi-participant collection.
- `data/new_data_training_full.json`: full cleaned May 21 dataset with embedded IMU frames.
- `data/new_data_cleaning_report.json`: dropped-sample report for the May 21 cleaning pass.
- `data/New training set/combined_training_samples_full.json`: merged training file containing the original 2-participant set plus the cleaned May 21 5-participant set.
- `data/cleaned_training_v2/cleaned_training_samples_full.json`: stricter six-gesture training set after motion-quality and class-outlier filtering.

Model analysis outputs:

- `notebooks/six_gesture_model_training.ipynb`: notebook version of the six-class model training and evaluation flow.
- `outputs/six_gesture_cleaning_report.json`: cleaning decisions and original-vs-cleaned six-class evaluation metrics.
- `models/six_gesture_logreg_pca_model.pkl`: sklearn logistic-regression/PCA model trained on the cleaned v2 six-gesture dataset.
- `outputs/six_gesture_model_report.json`: final six-class model comparison with accuracy, precision, recall, F1, confusion matrices, and participant-held-out scores. Current selected model: `kbest200_logistic_regression`.
- `models/six_gesture_final_model.pkl`: selected final six-class sklearn model trained on the cleaned v2 dataset. Current LOPO macro F1 is `0.522`, and random holdout macro F1 is `0.852`.
- `iPhone App/Gesture2AudioUser/Gesture2AudioUser/six_gesture_model.json`: iPhone-readable export of the selected six-class model, including scaler values, selected feature indices, and logistic-regression coefficients.

iPhone/watch demo app:

- `iPhone App/Gesture2AudioUser/Gesture2AudioUser.xcodeproj`

Current live audio path:

- Apple Watch capture -> iPhone classification -> embedded HTML sound engine in `WKWebView`
- `happy / neutral / sad` mood buttons drive the HTML DSP chain
- six supported gestures are `leaf`, `tree`, `bird`, `ocean`, `river`, and `rain`
- the embedded engine is based on `Gesture2Audio/G2A_Soundscape`'s `soundscape-generator`, with sample-pool metadata, local bundled soundscape data, and gesture-triggered source activation through the native bridge
