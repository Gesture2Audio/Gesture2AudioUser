# G2A Project Brief

Last updated: 2026-05-11

## Core Idea

G2A is an affect-aware gestural soundscape system. A user wears an Apple Watch, performs a rapid hand shake to trigger capture, then draws a gesture in mid air. The Apple Watch IMU stream is used for gesture recognition on the iPhone. Each recognized gesture adds a corresponding nature sound layer to the current headphone soundscape.

The system also reads physiological and mindfulness-related signals from the Apple Watch to estimate whether the user is calm or stressed. Instead of simply matching the user's state, the audio engine gradually regulates the soundscape toward calm.

## Gesture Set

| Gesture | Sound Layer |
| --- | --- |
| leaf | rustling leaves |
| wave / ocean | ocean waves |
| tree | forest ambience |
| fish / river | river stream |
| bird | bird chirps |
| cloud / rain | rain |

Note: the current raw dataset labels include `leaf`, `ocean`, `tree`, `river`, `bird`, and `rain`. The research description uses user-facing gesture names such as `wave`, `fish`, and `cloud`. The app should keep a clear mapping between user-facing gesture names and dataset/model labels.

## Interaction Flow

1. User wears Apple Watch and headphones.
2. User performs a rapid shake gesture.
3. The watch or phone detects the shake and starts a short recording window.
4. Apple Watch IMU frames are streamed or transferred to the iPhone.
5. The iPhone gesture model predicts one of the six gestures.
6. The matching nature sound is added as a new audio layer.
7. The system continuously monitors heart rate, heart rate variability, and available mindfulness-related state.
8. Mood inference classifies the user as calm or stressed.
9. The audio engine gradually changes active sound parameters to support mood regulation.

## Audio Behavior

Audio layers are additive. A new gesture should not stop previous sounds by default.

Example:

```text
bird gesture -> bird chirps begin
wave gesture -> ocean layer fades in over bird chirps
tree gesture -> forest layer fades in over the existing bird + ocean mix
```

Each layer should have independent volume and processing controls so the regulation engine can shape the overall soundscape without losing the user's authored composition.

## Mood-Regulation Strategy

Initial mood states:

- calm
- stressed

The first prototype should use gradual transitions, not abrupt changes. When stress is detected, the soundscape should move toward calmer characteristics over a transition period.

Candidate stressed-state regulation actions:

- fade down sharp or high-frequency elements
- soften bird chirps if they become too prominent
- reduce total mix intensity
- slightly reduce dense overlapping layers
- prioritize smoother layers such as rain, river, ocean, and leaves
- add gentle reverb or smoothing where appropriate
- avoid sudden starts, stops, or parameter jumps

Candidate calm-state behavior:

- preserve the user's current mix
- allow gentle enrichment
- keep changes subtle and slow
- avoid overstimulation from too many loud layers

## System Architecture

```text
Apple Watch IMU
   -> shake trigger detection
   -> gesture recording window
   -> iPhone gesture-recognition model
   -> gesture-to-sound mapping
   -> layered soundscape engine
   -> physiological mood inference
   -> gradual audio regulation
   -> headphone playback
```

## Current Data Notes

Raw samples are stored under:

```text
G2A_Raw_Data/G2A
```

Observed dataset labels on 2026-05-11:

| Label | File count |
| --- | ---: |
| bird | 44 |
| leaf | 71 |
| ocean | 97 |
| rain | 72 |
| river | 48 |
| tree | 51 |

Sample JSON fields observed:

- `createdAtEpoch`
- `durationSeconds`
- `sampleRateHz`
- `day`
- `sampleId`
- `sourceGesture`
- `soundHint`
- `frames`
- `label`

Each frame includes accelerometer and gyroscope values:

- `ax`, `ay`, `az`
- `gx`, `gy`, `gz`
- `elapsedSeconds`
- `timestampEpoch`
- `sampleClass`

## Near-Term Work Plan

1. Dataset audit
   - validate all JSON files are readable
   - count samples per gesture
   - check recording duration and sample rate consistency
   - detect missing IMU fields or corrupted samples

2. Preprocessing pipeline
   - load JSON frames into a structured format
   - normalize sequence length or support variable-length modeling
   - separate train, validation, and test sets
   - preserve gesture labels and sample IDs

3. Gesture model baseline
   - train an initial six-class model
   - evaluate confusion matrix and per-class accuracy
   - identify weak gestures that need more data

4. Runtime recognition design
   - define shake trigger threshold and debounce behavior
   - define gesture recording window length
   - define prediction confidence threshold
   - define fallback when confidence is low

5. Audio engine prototype
   - implement six loopable sound layers
   - add fade-in for new layers
   - support independent volume/filter/reverb controls
   - prevent clipping when many layers overlap

6. Mood inference prototype
   - start with calm/stressed classification
   - use heart rate and HRV trends rather than one-off readings
   - add smoothing to avoid frequent mood flipping

7. Gradual regulation engine
   - map calm/stressed state to audio target parameters
   - interpolate toward targets over time
   - log state transitions for research analysis

## Open Questions

- What exact Apple Watch and iPhone app stack will be used: native Swift/WatchKit only, or a hybrid app?
- Will shake detection run on the watch for responsiveness, or on the phone after streaming IMU frames?
- What duration should the gesture capture window use in production?
- What sound assets will be used, and are they loop-safe?
- What HRV window and stress threshold should be used for the first prototype?
- How will mindfulness output be represented in the app, and is it continuous or session-based?
- What study protocol will evaluate whether the system supports mood regulation?

