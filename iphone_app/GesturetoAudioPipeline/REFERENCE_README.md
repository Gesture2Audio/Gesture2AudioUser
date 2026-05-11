
# GesturetoAudio

GesturetoAudio is an Apple Watch + iPhone SwiftUI app for gesture-driven audio interaction.

## Overview
The watch app streams IMU motion data, detects shake events, and captures short motion windows. The iPhone companion app receives live debug telemetry from the watch and stores each captured session as a day-wise JSON file.

## Current Capabilities
- Apple Watch motion sensing with CoreMotion
- Shake detection trigger on watch
- Timed gesture capture window after shake
- Live watch-to-phone telemetry via WatchConnectivity
- iPhone debug dashboard for connection, state, and IMU values
- Day-wise JSON capture storage on iPhone in app sandbox

## Project Structure
- `GesturetoAudio Watch App/`: watchOS app (capture and sensor pipeline)
- `GesturetoAudio/`: iOS app (debug UI and storage receiver)
- `GesturetoAudio.xcodeproj/`: Xcode project configuration

## Output Data
Captured gestures are stored under day folders in the iPhone app sandbox. Each file name follows `timestamp_day_class.json`, and each IMU sample contains the six motion values plus its timestamp and class.

## Tech Stack
- Swift
- SwiftUI
- CoreMotion
- WatchConnectivity
