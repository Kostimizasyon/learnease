# Learnese

**Learnese** is an Android-only "instant replay" recorder for device audio output. While a session is active, Learnese continuously buffers the last **X seconds** of internal playback audio in memory. Tapping the draggable floating overlay button saves those last X seconds as a clip without interrupting capture.

## Features (Planned & Implemented)

- **Rolling in-memory audio buffer** (1–180s, fixed per session; presets 15s / 30s / 60s / 120s + custom).
- **Audio output only**: captures playback through speaker/headphones via Android `AudioPlaybackCapture` — never the microphone.
- **Floating overlay button**: draggable, edge-snapping, semi-transparent, with tap-to-save feedback and drag-to-dismiss (which ends the session).
- **Session-grouped library**: browse sessions newest-first, play clips with seek, rename sessions/clips/folders, and organize into nested folders.
- **Light & dark themes** following the system theme.

## Requirements

- **Android 10 (API 29) or higher** (required for `AudioPlaybackCaptureConfiguration`).
- Flutter SDK (`3.47+` / Dart `3.13+`) and Android SDK / JDK 17 for building.
- Android-only: no iOS or web targets.

## Build, Run & Test

```bash
# Install Dart/Flutter dependencies
flutter pub get

# Run static analysis
flutter analyze

# Run Dart & Flutter unit/widget tests
flutter test

# Run on a connected Android 10+ device or emulator
flutter run
```

## Permissions Explained

Learnese declares only the minimum permissions required (wired in Chunk 3):

| Permission | Why it is needed |
| --- | --- |
| `RECORD_AUDIO` | Required by Android's `AudioRecord` API even when capturing internal playback. Learnese never opens or records from the microphone. |
| `FOREGROUND_SERVICE` | Keeps the rolling audio buffer alive while you switch to other apps. |
| `FOREGROUND_SERVICE_MEDIA_PROJECTION` | Required on Android 14+ (API 34+) for foreground services holding a `MediaProjection`. |
| `POST_NOTIFICATIONS` | Required on Android 13+ (API 33+) to show the persistent session notification and its Stop action. |
| `SYSTEM_ALERT_WINDOW` | Allows displaying the small floating save button over other apps during an active session. |

Learnese does **not** request `INTERNET` (release builds) or broad external storage permissions — saved clips are stored in app-specific private storage.

## Known Limitations & Privacy Notes

- **App opt-out & DRM**: Android allows third-party apps to disallow audio playback capture (`allowAudioPlaybackCapture="false"`) and blocks DRM/protected content (e.g., streaming video or protected media). Those apps will capture as silence.
- **Continuous capture cost**: While a session is active, audio capture runs continuously in a foreground service. This uses battery and RAM proportional to your chosen buffer length **X**, and Android displays its standard casting/recording status indicator.
- **Per-session consent (Android 14+)**: Android 14+ treats `MediaProjection` tokens as single-use, so the system screen-capture consent dialog must be confirmed each time you start a new session.
- **Memory-only buffer**: Unsaved audio in the rolling buffer stays strictly in RAM and is never written to disk. Ending a session discards the unsaved buffer immediately.
