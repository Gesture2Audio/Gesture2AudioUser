# HTML Audio Restoration Notes

This document records the audio-related changes made during the recent debugging pass and the final intended architecture.

## Standing rule

From this point on, `soundscape_embed.html` is the source of truth for the sound design.

The following parts should stay exactly as provided unless there is explicit approval to change them:

- mood filter shapes
- frequency values
- playback-rate values
- fade timings
- gain targets
- analyser / waveform behavior
- the overall WebAudio flow

In practice, this means future work should focus on:

- Swift and `WKWebView` integration
- asset-loading reliability
- bridge code
- retry and error handling
- iOS compatibility fixes

without changing the engineer-tuned DSP behavior.

## Goal

Keep the `soundscape_embed.html` engine in charge of:

- WebAudio playback
- mood-dependent filter changes
- fade in / fade out transitions
- waveform analysis and rendering
- active layer state reported back to Swift

Swift should only:

- host the `WKWebView`
- pass mood / gesture events into the HTML engine
- receive status and error updates from the HTML engine
- configure the iOS audio session

## What changed before restoration

These changes were made during the earlier debugging cycle:

1. Added `AVAudioSession` setup in `PhoneDebugSession.swift`
   - This remains useful and is still kept.
   - It ensures the app is allowed to play audio on iOS.

2. Replaced HTML-owned audio playback with native `AVAudioPlayer` playback in `SoundscapeWebController.swift`
   - This moved audio, mood changes, and state tracking into Swift.
   - That solved some loading failures but changed the product behavior.
   - It no longer matched the HTML engine's filters, fades, analyser, or waveform behavior.

3. Replaced the original HTML engine with a simplified visualization-only page
   - The simplified page displayed mood and activity state but no longer performed the original WebAudio work.
   - This is the behavior that was reported as "completely different."

## Final restoration

The app has now been restored to use the HTML engine again.

### `soundscape_embed.html`

Restored the original WebAudio-based engine behavior:

- audio buffers are loaded in JavaScript
- `AudioContext` is resumed in the page
- mood changes rebuild the filter chain
- active layers are faded and restarted by the page
- the analyser drives the waveform canvas
- state and errors are posted back to Swift through `soundscapeBridge`

One reliability fix was kept:

- failed audio loads now clear the pending `loading[name]` entry so the sound can be retried later instead of getting stuck in a failed promise state

### `SoundscapeWebController.swift`

Restored the original Swift-to-HTML bridge behavior:

- `setMood(_:)` calls `window.g2a.setMood(...)`
- `activateGesture(label:)` calls `window.g2a.ensureSound(...)`
- `reset()` calls `window.g2a.reset()`
- `primeAudio()` calls `window.g2a.primeAudio()`
- active layer and status updates come back from HTML through script messages

Removed the native `AVAudioPlayer` sound engine from Swift.

### `WKURLSchemeHandler`

Added a custom `WKURLSchemeHandler` for the `g2audio://` scheme.

Reason:

- the WAV files are bundled into the app root
- direct `fetch(file://...)` from `WKWebView` is unreliable for this use case on iOS
- the custom scheme lets the HTML `fetch()` audio files reliably without changing the HTML engine design

The Swift host now injects:

- `g2audio://bundle/birds.wav`
- `g2audio://bundle/river.wav`

through `window.g2aAssetURLs`.

This keeps the HTML logic intact while solving the loading problem at the host layer.

### `PhoneDebugSession.swift`

Kept the audio session configuration:

- imports `AVFoundation`
- configures `AVAudioSession` with `.playback`
- activates the session during startup

This supports the HTML engine's audio output on iOS.

## Intended architecture after this fix

1. Swift loads `soundscape_embed.html` in a `WKWebView`
2. Swift injects custom audio URLs via `window.g2aAssetURLs`
3. HTML fetches and decodes bundled audio through the custom `g2audio://` scheme
4. HTML performs all mood-based DSP, fades, playback rate changes, and waveform rendering
5. HTML reports state back to Swift
6. Swift updates the app UI from those state messages

## Files involved

- `iPhone App/Gesture2AudioUser/Gesture2AudioUser/PhoneDebugSession.swift`
- `iPhone App/Gesture2AudioUser/Gesture2AudioUser/SoundscapeWebController.swift`
- `iPhone App/Gesture2AudioUser/Gesture2AudioUser/soundscape_embed.html`

## Change log practice

For every future audio-related change:

1. update this document
2. describe what changed in plain, human language
3. note whether the change touched:
   - HTML engine behavior
   - Swift bridge behavior
   - asset loading
   - iOS session / playback setup
4. explicitly say whether the engineer-tuned DSP values were preserved

## Change log

### 2026-05-12

- restored the HTML/WebAudio engine as the audio source of truth
- removed the native `AVAudioPlayer` replacement path
- added a `WKURLSchemeHandler`-based loading path for bundled WAV files
- kept iOS audio-session setup in Swift
- documented that future changes must preserve the engineer-tuned frequency and speed manipulations unless explicitly approved
- refined the `WKURLSchemeHandler` path after web research:
  - the main HTML page and the WAV assets now load from the same `g2audio://` custom origin
  - the scheme handler now returns `HTTPURLResponse` objects with explicit `Content-Type` and `Content-Length` headers
  - this change was made to avoid `fetch()` failures caused by status `0` / `response.ok === false` behavior and mixed-origin access-control problems in `WKWebView`
- added an HTML-side audio unlock flow for `WKWebView`:
  - the page now asks for one real tap inside the preview to unlock the WebAudio context
  - a silent inline media element is used during that tap to help satisfy iOS media activation rules
  - this was added because native Swift button taps do not reliably count as WebAudio user gestures inside the embedded web view
- engineer-tuned DSP values in `soundscape_embed.html` were preserved
