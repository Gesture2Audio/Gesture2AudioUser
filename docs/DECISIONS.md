# Decision Log

Use this file for durable research and engineering decisions. Each decision should include the date, decision, reason, and consequences.

## 2026-05-11 - Six Fixed Gestures

Decision: The first system version uses six fixed gestures.

Mapping:

- leaf -> rustling leaves
- wave/ocean -> ocean waves
- tree -> forest ambience
- fish/river -> river stream
- bird -> bird chirps
- cloud/rain -> rain

Reason: A fixed gesture set keeps the first research prototype bounded and makes model training/evaluation practical.

Consequences:

- The dataset, model labels, app UI, and sound engine must preserve a stable six-class mapping.
- User-facing gesture names may differ from dataset labels, so the mapping must be explicit.

## 2026-05-11 - Recognition Runs on iPhone

Decision: Apple Watch IMU data is used as input, but gesture recognition runs on the iPhone.

Reason: The iPhone gives more practical compute, storage, debugging, and audio integration options for the prototype.

Consequences:

- The watch must capture or stream IMU frames reliably.
- The phone app owns preprocessing, inference, confidence handling, and sound triggering.

## 2026-05-11 - Sounds Are Layered

Decision: New gestures add sound layers on top of existing layers instead of replacing them.

Reason: The interaction is intended to let users compose a soundscape over time.

Consequences:

- The audio engine needs per-layer controls.
- The mix must prevent clipping and overstimulation as layers accumulate.
- The system needs a future policy for layer limits, decay, muting, or reset.

## 2026-05-11 - Mood Regulation Uses Gradual Transitions

Decision: Mood adaptation regulates the soundscape gradually rather than applying abrupt audio changes.

Reason: Sudden audio changes may be intrusive and could conflict with the goal of reducing stress.

Consequences:

- Mood inference should be smoothed.
- Audio parameters should interpolate toward calm/stressed target settings.
- Transition timing becomes a tunable research parameter.

