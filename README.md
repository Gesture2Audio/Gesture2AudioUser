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

iPhone/watch demo app:

- `iPhone App/Gesture2AudioUser/Gesture2AudioUser.xcodeproj`
