# Demo Pipeline

This is the short pipeline for showing gesture separation from the cleaned dataset.

## Data

Use:

```text
data/training_samples_full.json
```

It contains the approved 277 samples and the embedded Apple Watch IMU frame values.

For a simple supervisor demo, separate two gestures first:

```text
bird vs fish
```

In the model data, `fish` is stored as the `river` label because the fish gesture triggers the river sound.

## Command

Open and run:

```text
notebooks/binary_gesture_demo.ipynb
```

The notebook:

1. loads the full training JSON
2. filters the two selected gestures
3. converts each gesture into a fixed-length IMU sequence
4. adds simple motion features
5. trains a small classifier
6. prints cross-validation accuracy, held-out accuracy, and a confusion matrix

## Why This Demo Works

This does not try to solve the full six-gesture problem yet. It proves the basic pipeline:

```text
Apple Watch IMU data -> preprocessing -> gesture classifier -> predicted gesture
```

Once this works clearly for two gestures, the same pipeline can be expanded to all six gestures.
