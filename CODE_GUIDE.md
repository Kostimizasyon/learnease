# Learnese Code Guide

This document explains how Learnese is structured and how its Dart and Android (Kotlin) layers interact.

## Architecture Overview

Learnese separates concerns across three thin layers with no heavy state-management framework (standard `ChangeNotifier` / `ValueNotifier` + `ListenableBuilder`):

1. **Flutter UI (`lib/pages/`, `lib/theme/`)**: Session setup, active session screen, library/folder browser, dialogs, and clip playback (`just_audio`).
2. **Dart Services & Models (`lib/data_models/`, `lib/services/`)**: Immutable domain models, SQLite persistence (`sqflite`), file storage, preferences, permission flows, and a platform-channel wrapper (`recorder_channel.dart`).
3. **Android Native Engine (`android/app/src/main/kotlin/com/learnese/app/`)**: Foreground service (`RecordingService`), playback audio capture + ring buffer (`AudioCaptureEngine`), draggable overlay (`OverlayController`), notification builder (`NotificationFactory`), and consent/channel host (`MainActivity`).

## Planned Dart <-> Kotlin Data Flow

- **Commands (`MethodChannel`)**:
  - `startSession(bufferSeconds: int)` -> requests `MediaProjection` consent in `MainActivity`, then starts `RecordingService`.
  - `saveClip()` -> snapshots the in-memory ring buffer and encodes to disk on a background worker thread without interrupting capture.
  - `stopSession()` -> flushes any in-flight save, stops `AudioRecord`, releases `MediaProjection`, removes the overlay and notification, clears RAM buffer, and emits `idle`.
- **State Stream (`EventChannel`)**:
  - Kotlin pushes `{sessionState, bufferedMs, bufferSeconds, lastSavedClipPath?, lastSavedClipDurationMs?, lastSavedClipSizeBytes?, error?, errorMessage?}`.
  - Dart deserializes each event via `RecordingState.fromMap(...)`.

## Rolling Buffer Design & Recording Lifecycle

1. User chooses buffer length **X** (1–180 seconds; fixed for the entire session, no auto-stop or session timer).
2. After projection consent, `RecordingService` allocates a fixed-size byte ring buffer sized for **X** seconds of 16-bit PCM audio.
3. `AudioRecord` (configured via `AudioPlaybackCaptureConfiguration` with `USAGE_MEDIA`, `USAGE_GAME`, and `USAGE_UNKNOWN`) continuously appends captured PCM frames into the ring buffer, overwriting the oldest samples once full.
4. Nothing is written to disk until the user taps the floating overlay button (or triggers `saveClip()`).
5. On save, the ring buffer is snapshotted in chronological order (oldest -> newest, handling wrap-around and partial fill if `< X` seconds have elapsed) and written as a 44.1 kHz 16-bit mono `.wav` (44-byte RIFF header + PCM bytes) on a background worker thread.
6. Ending a session via overlay drag-to-dismiss, notification Stop, in-app Stop, or system projection revocation goes through the single `stopSession()` cleanup path.

## Data Models & SQLite Schema (Chunk 1 -> Chunk 2)

All timestamps (`started_at`, `ended_at`, `created_at`) are persisted as **Unix epoch milliseconds (`INTEGER`)** for fast, unambiguous SQLite sorting and exact round-trip equality (`DateTime.fromMillisecondsSinceEpoch`). Models omit `id` from `toMap()` when `id == null` so SQLite `AUTOINCREMENT` assigns primary keys cleanly.

- `RecordingSession` (`sessions`): `id`, `name`, `started_at`, `ended_at?`, `buffer_seconds`, `folder_id?` (`ON DELETE SET NULL` when a folder is deleted so recorded sessions are preserved at root instead of lost).
- `AudioClip` (`clips`): `id`, `session_id` (`ON DELETE CASCADE`), `name`, `file_path`, `duration_ms`, `size_bytes`, `created_at`.
- `Folder` (`folders`): `id`, `name`, `parent_id?` (self-FK with `ON DELETE CASCADE` for sub-folders; `FolderRepository.moveFolder()` guards against self/descendant cycles), `created_at`.
- `RecordingState`: Wire model for `EventChannel` updates (`SessionStatus.idle | active`, `CaptureError`, `bufferFillFraction`).

### Storage Layout (`StorageService`)
- Saved `.wav` clips live in app-specific documents storage under `clips/session_<sessionId>/clip_<epochMs>.wav` (with numeric collision suffix if multiple saves land in the same millisecond).
- `SessionRepository.deleteClip()` and `SessionRepository.deleteSession()` delete both the SQLite rows and the corresponding `.wav` files/session directory via `StorageService`.

## Theme & Color System

- Every Dart color lives in `lib/theme/app_colors.dart`; UI widgets must never embed raw hex values.
- `AppTheme.light()` and `AppTheme.dark()` configure Material 3 with a deep teal primary, neutral near-white / near-black surfaces, and a red accent exposed via the `AppRecordingColors` `ThemeExtension` reserved strictly for active recording state and destructive/dismiss actions.
- Native overlay and notification colors live in `android/app/src/main/res/values/colors.xml` and mirror `AppColors`.

## Key Gotchas

- **Android 14+ single-use projection tokens**: `MediaProjection` cannot be reused after a session stops; `MainActivity` must request fresh user consent for every new session.
- **App opt-outs & DRM**: Apps setting `allowAudioPlaybackCapture="false"` or playing DRM streams output silence by OS design.
- **Overlay lifetime = Session lifetime**: Dismissing the overlay must always terminate the session; there is no hidden background capture mode.

## Extending the Codebase

- Keep pure logic (ring buffer wrap-around, file naming, model transformations) free of Android `Context`/Flutter widget dependencies so it remains unit-testable via JUnit and `flutter test`.
- Follow the **Rule of 3** for UI widgets: extract repeated UI blocks only once used 3+ times, and prefer semantic named constructors (e.g., `Folder.root()`, `Folder.nested()`, `RecordingState.active()`).
