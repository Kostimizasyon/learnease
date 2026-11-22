# Learnese

**Learnese** is an Android-only "instant replay" recorder for device audio output. While a session is active, Learnese continuously buffers the last **X seconds** of internal playback audio in memory. Tapping the draggable floating overlay button saves those last X seconds as a lossless `.wav` clip without interrupting capture.

## Features

- **Rolling in-memory audio buffer**: Choose 1–180s (presets 15s / 30s / 60s / 120s + custom), fixed for the session with no auto-stop or session timer.
- **Audio output only**: Captures internal playback (`USAGE_MEDIA`, `USAGE_GAME`, `USAGE_UNKNOWN`) via `AudioPlaybackCaptureConfiguration` — never the microphone.
- **Draggable floating overlay button**: 52dp semi-transparent bubble with a pulsing live indicator, animated edge snapping, debounced tap-to-save with teal check flash, and drag-to-X dismiss (which ends the session).
- **Persistent session notification**: Shows buffer length `X` and saved clip count, opens the Active Session screen on tap, and includes a **Stop Session** action.
- **Session-grouped library & playback**: Browse sessions newest-first, organize into nested folders with breadcrumbs, rename/move/delete items, and play clips with seek and ±5s skip.
- **Adaptive launcher icon & system themes**: Material 3 light/dark themes following the system setting and an Android adaptive + monochrome launcher icon.

## Requirements

- **Android 10 (API 29) or higher** (required for `AudioPlaybackCaptureConfiguration`).
- Flutter SDK (`3.47+` / Dart `3.13+`), Android SDK (API 37 for `compileSdk`), and JDK 17+.
- Android-only: no iOS or web targets.

## Build, Run & Test

```bash
# Install Dart/Flutter dependencies
flutter pub get

# Regenerate Android adaptive & monochrome launcher icons from assets/icon/
dart run flutter_launcher_icons

# Run static analysis
flutter analyze

# Run Dart & Flutter unit/widget tests
flutter test

# Run Android Kotlin JUnit tests
cd android && ./gradlew :app:testDebugUnitTest

# Run on a connected Android 10+ device or emulator
flutter run

# Build a release APK
flutter build apk --release
```

## Permissions Explained

Learnese declares only the minimum permissions required in `android/app/src/main/AndroidManifest.xml`:

| Permission | Why it is needed |
| --- | --- |
| `RECORD_AUDIO` | Required by Android's `AudioRecord` API even when capturing internal playback. Learnese never opens or records from the microphone. |
| `FOREGROUND_SERVICE` | Keeps the rolling audio buffer alive while you switch to other apps. |
| `FOREGROUND_SERVICE_MEDIA_PROJECTION` | Required on Android 14+ (API 34+) for foreground services holding a `MediaProjection`. |
| `POST_NOTIFICATIONS` | Required on Android 13+ (API 33+) to show the persistent session notification and its Stop action. |
| `SYSTEM_ALERT_WINDOW` | Allows displaying the small floating save button over other apps during an active session. |

Learnese does **not** request `INTERNET` (release builds) or broad external storage permissions — saved `.wav` clips are stored in app-specific private storage (`clips/session_<id>/`).

## Known Limitations & Privacy Notes

- **App opt-out & DRM**: Android allows third-party apps to disallow audio playback capture (`allowAudioPlaybackCapture="false"`) and blocks DRM/protected content (e.g., streaming video or protected media). Those apps will capture as silence.
- **Continuous capture cost**: While a session is active, audio capture runs continuously in a foreground service. This uses battery and RAM proportional to your chosen buffer length **X** (~86.1 KiB/s, up to ~15.1 MiB at 180s mono), and Android displays its standard casting/recording status indicator.
- **Per-session consent (Android 14+)**: Android 14+ treats `MediaProjection` tokens as single-use, so the system screen-capture consent dialog must be confirmed each time you start a new session.
- **Memory-only buffer**: Unsaved audio in the rolling buffer stays strictly in RAM and is never written to disk. Ending a session wipes and discards the unsaved buffer immediately.

## Manual QA Checklist (Android 10–17 Physical Device)

- [ ] **Permissions & consent**: Fresh install -> tap **Record Now** -> grant audio capture, notifications, and Display Over Other Apps (verify returning from Android Settings refreshes the gate automatically) -> confirm Android screen-capture consent.
- [ ] **Consent cancellation**: Tap **Record Now** -> tap **Cancel** on Android screen-capture dialog -> verify cancellation message shows and no empty session is created in Library.
- [ ] **Overlay ergonomics**: Switch to YouTube/podcast app -> drag floating button across screen (verify edge snapping, smooth landscape rotation reclamp, and minimal footprint).
- [ ] **Capture & partial fill**: Tap floating button 3–5 seconds after starting a 30s session -> verify teal check flash and saved clip plays cleanly with exact ~3–5s duration.
- [ ] **Rolling wrap-around**: Play audio longer than buffer length `X` -> tap floating button -> verify saved clip contains only the *most recent* `X` seconds in chronological order with no mic bleed (speak out loud during playback and verify voice is NOT recorded).
- [ ] **Rapid saves & dismiss mid-save**: Tap floating button twice rapidly (~400ms apart), then drag floating button straight onto the bottom **X** dismiss target -> verify both clips save intact, overlay and notification disappear, and session is marked ended.
- [ ] **Notification controls**: Start a session -> tap the ongoing notification from another app (verify Learnese opens directly on **Active Session**) -> tap **Stop Session** on the notification (verify overlay vanishes and session ends).
- [ ] **Mid-session revocation**: Revoke Display Over Other Apps or screen casting from Android status bar while recording -> verify session stops cleanly with an explanatory banner on Home.
- [ ] **Library & organization**: Create nested folders (`A -> B -> C`), navigate breadcrumbs, rename session/clip/folder, move session into `B`, delete folder `A` (verify `B` & `C` cascade delete while sessions return safely to Library root), play clips with seek bar and ±5s skip, delete clip/session and verify playback/storage cleanup.
- [ ] **Theme & icon**: Toggle Android Light / Dark mode and Android 13+ themed monochrome icons -> verify legible contrast and crisp adaptive/monochrome launcher icon.
