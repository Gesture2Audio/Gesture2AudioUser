# iPhone Pipeline

This is the active live six-gesture demo app.

Project:

```text
iPhone App/Gesture2AudioUser/Gesture2AudioUser.xcodeproj
```

## Demo Flow

1. Run the iPhone app on the phone.
2. Run the Watch app on the paired Apple Watch.
3. Shake the watch to trigger a 3-second capture.
4. Draw one of the six supported gestures.
5. The watch transfers the captured IMU sequence to the phone.
6. The iPhone extracts the same 652 IMU features used in the notebook.
7. The iPhone scales those features, keeps the selected 200 features, and runs the six-class logistic-regression model.
8. The detected gesture is sent to the embedded HTML sound engine.
9. The HTML engine adds the matching audio layer without stopping the existing layers.
10. The user can switch `happy`, `neutral`, and `sad` manually; the selected mood immediately changes the active audio processing chain.

## Gestures And Layers

```text
leaf   -> rustling leaves
tree   -> forest sound
bird   -> bird chirps
ocean  -> ocean waves
river  -> river sound
rain   -> rain sound
```

The user-facing gesture names are shown as Leaf, Tree, Bird, Wave, Fish, and Cloud. Internally, the trained labels remain `leaf`, `tree`, `bird`, `ocean`, `river`, and `rain`.

## What Is Implemented

- Apple Watch IMU capture at 50 Hz.
- Shake-triggered 3-second gesture window.
- Phone-side six-gesture classification after each transferred capture.
- Embedded HTML/JavaScript audio engine inside the iPhone app through `WKWebView`.
- Additive audio layers for all six detected gestures.
- Default transient processing on the phone:
  - classify immediately
  - do not persist raw captures
- Optional research save mode on the phone for debugging and later analysis.
- Native mood buttons that drive the HTML sound-characteristics logic.
- Bundled local audio files:
  - `audio/birds.wav`
  - `audio/river.wav`
- Local HTML-generated sources:
  - `leaf`
  - `tree`
  - `ocean`
  - `rain`
- The web-derived sample-pool generator and `Load Sounds` flow are intentionally not used in the app bundle right now.

## Model

Bundled model file:

```text
iPhone App/Gesture2AudioUser/Gesture2AudioUser/six_gesture_model.json
```

Export script:

```text
scripts/export_six_gesture_ios_model.py
```

Training script:

```text
scripts/train_six_gesture_model.py
```

Training data source:

```text
data/cleaned_training_v2/cleaned_training_samples_full.json
```

Model details:

- model type: `kbest200_logistic_regression`
- classifier: multi-class logistic regression
- classes: `leaf`, `tree`, `bird`, `ocean`, `river`, `rain`
- training samples: `940`
- extracted features per gesture: `652`
- selected features used by classifier: `200`
- input channels:
  - `ax`, `ay`, `az`
  - `gx`, `gy`, `gz`
- derived channels:
  - acceleration magnitude
  - gyroscope magnitude
- feature extraction:
  - first-five-frame baseline correction
  - 128-frame interpolation
  - signal, delta, and delta2 statistics
  - channel correlations
  - 64-frame resampled raw IMU shape

## Validation

Latest selected model:

```text
kbest200_logistic_regression
```

Current metrics:

```text
Random holdout accuracy: 0.851
Random holdout macro F1: 0.852

LOPO accuracy: 0.520
LOPO macro F1: 0.522
```

The random-holdout result is the expected known-user/calibrated-user demo behavior. The LOPO result is the honest unseen-participant result and remains the main research limitation.

## Current Limitation

This app classifies after each 3-second transferred capture reaches the phone. It is not continuous rolling-window classification yet.

The six-class model is now integrated for the app demo, but unseen-user generalization is still weak. The current audio path is local-only: bird and river use bundled WAV files, while leaf, tree, ocean, and rain are generated inside the embedded HTML engine.
