# iPhone Pipeline

This app is the first live pipeline for the bird/fish demo.

Project:

```text
iphone_app/GesturetoAudioPipeline/GesturetoAudio.xcodeproj
```

## Demo Flow

1. Open the Xcode project.
2. Run the iPhone app target on the iPhone.
3. Run the Watch app target on the paired Apple Watch.
4. On the watch, shake to start capture.
5. Draw a bird or fish gesture for the 3-second capture window.
6. The watch transfers the captured IMU frames to the iPhone.
7. The iPhone classifies the capture as `bird` or `river`.
8. The iPhone starts the matching sound layer:
   - `bird` -> bird chirps
   - `river` -> river sound
9. The next gesture adds another layer without stopping the previous one.

Before running on physical devices, open Signing & Capabilities in Xcode and choose your Apple developer team for both the iPhone target and the Watch app target. The copied reference project had personal team IDs, so this repo clears them and uses neutral bundle identifiers.

## What Is Implemented

- Apple Watch IMU capture is based on the reference data-collection project.
- The watch still uses shake detection to trigger a 3-second capture window.
- The iPhone receives the captured JSON through WatchConnectivity.
- The iPhone classifies bird vs fish/river using a bundled nearest-neighbor model.
- The iPhone generates procedural bird and river sounds with AVAudioEngine.
- The soundscape is additive, so bird then fish gives bird chirps plus river sound.

## Model Data

Bundled app data:

```text
iphone_app/GesturetoAudioPipeline/GesturetoAudio/bird_river_training.json
```

This file contains 91 approved samples:

- `bird`: 44
- `river`: 47

The user-facing fish gesture is stored as `river` in the dataset because it maps to the river sound.

## Validation

A Python mirror of the iPhone classifier was run against the bundled training file.

Result:

```text
5-fold CV accuracy: 0.901
Held-out accuracy: 0.913
Confusion matrix:
['bird', 'river']
[[11  0]
 [ 2 10]]
```

This is enough for a first pipeline test. It is not yet a final general-user model.

## Current Limitation

This first app does classification after each 3-second capture arrives on the iPhone. It is live for the demo flow, but it is not continuous frame-by-frame classification yet.

The next step is to replace the nearest-neighbor model with a Core ML model and classify directly from a rolling IMU window.
