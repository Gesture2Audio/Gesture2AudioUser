# iPhone Pipeline

This is the active live bird/fish demo app.

Project:

```text
iPhone App/Gesture2AudioUser/Gesture2AudioUser.xcodeproj
```

## Demo Flow

1. Run the iPhone app on the phone.
2. Run the Watch app on the paired Apple Watch.
3. Shake the watch to trigger a 3-second capture.
4. Draw either the bird gesture or the fish gesture.
5. The watch transfers the captured IMU sequence to the phone.
6. The iPhone classifies the sequence as `bird` or `river`.
7. The iPhone sends the detected source to the embedded HTML sound engine.
8. The HTML engine starts the matching layer:
   - `bird` -> bird chirps
   - `river` -> river sound
9. A second gesture adds the next layer without stopping the first one.
10. The user can switch the sound-characteristics mode manually with native `happy`, `neutral`, and `sad` buttons, which update the embedded HTML DSP chain.

## What Is Implemented

- Apple Watch IMU capture at 50 Hz.
- Shake-triggered 3-second gesture window.
- Phone-side classification after each transferred capture.
- Embedded HTML/JavaScript sound engine inside the iPhone app through `WKWebView`.
- Additive bird and river audio layers driven by the embedded page.
- Default transient processing on the phone:
  - classify immediately
  - do not persist raw captures
- Optional research save mode on the phone for debugging and later analysis.
- Native mood buttons that drive the HTML sound-characteristics logic.

## Model

Bundled model file:

```text
iPhone App/Gesture2AudioUser/Gesture2AudioUser/bird_river_model.json
```

Training script:

```text
scripts/train_bird_river_model.py
```

Embedded soundscape engine:

```text
iPhone App/Gesture2AudioUser/Gesture2AudioUser/soundscape_embed.html
```

Training data source:

```text
data/training_samples_full.json
```

Model details:

- model type: logistic regression
- classes: `bird`, `river`
- training samples: 91
- feature count: 416
- input channels:
  - `ax`, `ay`, `az`
  - `gx`, `gy`, `gz`
  - acceleration magnitude
  - gyroscope magnitude
- feature extraction:
  - fixed 151-frame window
  - 32-bin temporal downsampling
  - raw-signal summary statistics
  - delta-signal summary statistics

The user-facing fish gesture is stored as `river` in the dataset because it triggers the river sound layer.

## Validation

The trained model artifact was generated from the approved bird and river samples and evaluated during training.

Result:

```text
5-fold CV accuracy: 0.923
Held-out accuracy: 1.000
Held-out confusion matrix:
['bird', 'river']
[[11, 0], [0, 12]]
Leave-one-participant-out:
Nilakna -> 0.525
Nilesh  -> 0.490
```

The random-split demo accuracy is strong enough for the current bird/fish pipeline test. The participant-split result is still weak, which means the model is learning person-specific drawing style. For a general-user model, more participants are required.

## Current Limitation

This app is live after each 3-second gesture capture reaches the phone. It is not continuous rolling-window classification yet.

The next step is to move from transfer-per-capture inference to continuous live inference on the incoming IMU stream, then replace manual `happy/neutral/sad` control with automatic physiological-state mapping from heart rate, HRV, and mindfulness signals.
