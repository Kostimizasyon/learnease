# Learnese Code Guide

This document explains how Learnese is structured and how its Dart and Android (Kotlin) layers interact.

## Architecture Overview

Learnese separates concerns across three thin layers with no heavy state-management framework (standard `ChangeNotifier` / `ValueNotifier` + `ListenableBuilder`):

1. **Flutter UI (`lib/pages/`, `lib/theme/`)**: Session setup, active session screen, library/folder browser, dialogs, and clip playback (`just_audio`).
2. **Dart Services & Models (`lib/data_models/`, `lib/services/`)**: Immutable domain models, SQLite persistence (`sqflite`), file storage, preferences, permission flows, and a platform-channel wrapper (`recorder_channel.dart`).
3. **Android Native Engine (`android/app/src/main/kotlin/com/learnese/app/`)**: Foreground service (`RecordingService`), playback audio capture + ring buffer (`AudioCaptureEngine`), draggable overlay (`OverlayController`), notification builder (`NotificationFactory`), and consent/channel host (`MainActivity`).

## Dart <-> Kotlin Data Flow

- **Commands (`MethodChannel`: `com.learnese.app/recorder`)**:
  - `startSession({bufferSeconds: int, outputDir?: String})` -> validates `RECORD_AUDIO`, `Settings.canDrawOverlays`, and `1..180s` bounds, launches fresh `MediaProjection` consent in `MainActivity`, and starts `RecordingService`. Returns `true` if started or `false` if consent was cancelled/denied.
  - `saveClip()` -> snapshots `AudioRingBuffer` synchronously and writes a `.wav` file on `AudioCaptureEngine`'s single-threaded writer executor without interrupting capture; returns `{filePath, durationMs, sizeBytes}` and publishes an active event with `lastSavedClipPath`.
  - `stopSession()` -> detaches the floating overlay immediately, stops `AudioRecord`, wipes RAM buffer, awaits any in-flight `.wav` save to finish and flush, stops `MediaProjection`, removes the notification, and emits `idle`.
  - `getState()` -> fetches `RecordingSessionBus.latestState()` for UI synchronization.
  - `hasOverlayPermission()` / `openOverlayPermissionSettings()` -> queries `Settings.canDrawOverlays()` directly and deep-links to Learnese's Android "Display over other apps" settings screen.
  - `consumeOpenActiveSession()` & native-to-Dart `onOpenActiveSession` -> routes notification taps to the active session screen on both cold launch and warm resume.
- **State Stream (`EventChannel`: `com.learnese.app/recorder_events`)**:
  - Kotlin pushes `{sessionState, bufferedMs, bufferSeconds, lastSavedClipPath?, lastSavedClipDurationMs?, lastSavedClipSizeBytes?, error?, errorMessage?}` via `RecordingSessionBus` on the main looper.
  - Dart deserializes each event via `RecordingState.fromMap(...)` inside `RecorderChannel.stateStream`.

## Rolling Buffer Design & Recording Lifecycle

1. User chooses buffer length **X** (1–180 seconds; fixed for the entire session, no auto-stop or session timer).
2. After projection consent, `RecordingService` allocates a fixed-size byte ring buffer sized for **X** seconds of 16-bit PCM audio.
3. `AudioRecord` (configured via `AudioPlaybackCaptureConfiguration` with `USAGE_MEDIA`, `USAGE_GAME`, and `USAGE_UNKNOWN`) continuously appends captured PCM frames into the ring buffer, overwriting the oldest samples once full.
4. Nothing is written to disk until the user taps the floating overlay button (or triggers `saveClip()`).
5. On save, `AudioRingBuffer.snapshotAndClear()` atomically extracts the buffer in chronological order (oldest -> newest, handling wrap-around and partial fill if `< X` seconds have elapsed) and immediately zeroes/resets the buffer to `0` so the next clip starts fresh with no overlapping audio. The snapshot is written as a 44.1 kHz 16-bit mono `.wav` (44-byte RIFF header + PCM bytes) on a background worker thread.
6. Ending a session via overlay drag-to-dismiss, notification Stop, in-app Stop, or system projection revocation goes through the single `stopSession()` cleanup path.

## Data Models & SQLite Schema (Chunk 1 -> Chunk 2)

All timestamps (`started_at`, `ended_at`, `created_at`) are persisted as **Unix epoch milliseconds (`INTEGER`)** for fast, unambiguous SQLite sorting and exact round-trip equality (`DateTime.fromMillisecondsSinceEpoch`). Models omit `id` from `toMap()` when `id == null` so SQLite `AUTOINCREMENT` assigns primary keys cleanly.

- `RecordingSession` (`sessions`): `id`, `name`, `started_at`, `ended_at?`, `buffer_seconds`, `folder_id?` (`ON DELETE SET NULL` when a folder is deleted so recorded sessions are preserved at root instead of lost).
- `AudioClip` (`clips`): `id`, `session_id` (`ON DELETE CASCADE`), `name`, `file_path`, `duration_ms`, `size_bytes`, `created_at`.
- `Folder` (`folders`): `id`, `name`, `parent_id?` (self-FK with `ON DELETE CASCADE` for sub-folders; `FolderRepository.moveFolder()` guards against self/descendant cycles), `created_at`.
- `RecordingState`: Wire model for `EventChannel` updates (`SessionStatus.idle | active`, `CaptureError`, `bufferFillFraction`).

### UI Coordination (`SessionController`)
- `lib/services/session_controller.dart` (`ChangeNotifier`) bridges `RecorderChannel`, `SessionRepository`, `StorageService`, `PreferencesService`, and `PermissionService`.
- `HomePage` and `ActiveSessionPage` rebuild via `ListenableBuilder` with no third-party state framework.
- Whenever Kotlin emits a `lastSavedClipPath` event (from tapping the floating overlay or calling `saveClipNow`), `SessionController` deduplicates by path (`_persistedClipPaths`) and persists a numbered `AudioClip` (`Clip 1`, `Clip 2`, ...) into SQLite under the active session.
- If `MediaProjection` consent is cancelled, `SessionController.startSession()` rolls back the empty DB session row immediately.
- Tapping the ongoing Android notification sets tab index `0` via `onNavigateToActiveSession` (both warm resume and cold launch via `consumeOpenActiveSession()`), landing directly on `ActiveSessionPage`.

### Library & Playback (`LibraryController`, `LibraryPage`, `PlayerSheet`)
- `lib/services/library_controller.dart` (`ChangeNotifier`) coordinates `SessionRepository` + `FolderRepository` and listens to `SessionController` so newly saved clips and started/ended sessions appear in the Library automatically.
- `LibraryPage` displays folders above sessions (ordered newest-first), shows an interactive breadcrumb bar when inside sub-folders, and uses `AppDialog` (`rename`, `createFolder`, `confirmDelete`, `pickFolder`) for all organization actions.
- `PlayerSheet` wraps `just_audio`'s `AudioPlayer` behind `ClipAudioPlayer` (`JustAudioClipPlayer`), providing play/pause, seek slider, ±5s skip, previous/next clip navigation scoped strictly to `LibraryController.currentFolderPlayableClips` (clips inside the currently open folder), auto-rewind after completion, and widget-testable playback control.

### Storage Layout (`StorageService`)
- Saved `.wav` clips live in app-specific documents storage under `clips/session_<sessionId>/clip_<epochMs>.wav` (with numeric collision suffix if multiple saves land in the same millisecond).
- Dart passes the resolved session directory path to Kotlin when starting a session so both layers always write to and clean up the exact same directory (avoiding Android's `app_flutter/` vs `files/` mismatch).
- `SessionRepository.deleteClip()` and `SessionRepository.deleteSession()` delete both the SQLite rows and the corresponding `.wav` files/session directory via `StorageService`.

## Theme & Color System

- Every Dart color lives in `lib/theme/app_colors.dart`; UI widgets must never embed raw hex values.
- `AppTheme.light()` and `AppTheme.dark()` configure Material 3 with a deep teal primary, neutral near-white / near-black surfaces, and a red accent exposed via the `AppRecordingColors` `ThemeExtension` reserved strictly for active recording state and destructive/dismiss actions.
- Native overlay and notification colors live in `android/app/src/main/res/values/colors.xml` and mirror `AppColors`.

## Key Gotchas & Edge-Case Hardening

- **Android 14+ single-use projection tokens**: `MediaProjection` cannot be reused after a session stops; `MainActivity` always requests fresh user consent per session, and `RecordingService` calls `ServiceCompat.startForeground(..., FOREGROUND_SERVICE_TYPE_MEDIA_PROJECTION)` before `getMediaProjection()`.
- **App opt-outs & DRM**: Apps setting `allowAudioPlaybackCapture="false"` or playing DRM streams output silence by OS design.
- **Overlay lifetime = Session lifetime**: Dismissing the overlay (or revoking `SYSTEM_ALERT_WINDOW` mid-session) immediately stops the session via `RecordingService.stopSessionInternal()`.
- **Low storage & memory pressure**: `WavWriter` checks directory `usableSpace` with a 1 MiB headroom margin before writing and throws `InsufficientStorageException` (`storage_error`) rather than producing truncated files. `AudioCaptureEngine` guards `AudioRingBuffer` allocation and snapshotting against `OutOfMemoryError`.
- **Service killed while backgrounded**: `LearneseApp` observes `AppLifecycleState.resumed` and calls `SessionController.syncWithNative()` so if Android terminates `RecordingService` under memory pressure, the UI reconciles back to idle and closes the SQLite session row cleanly.
- **Stop while encoding**: `AudioCaptureEngine.stopAndFlush()` stops capture and wipes RAM immediately, then awaits `saveExecutor` termination on a background thread so any in-flight `.wav` write finishes and emits its clip event before `idle` is published.

## Extending the Codebase

- Keep pure logic (ring buffer wrap-around, file naming, model transformations) free of Android `Context`/Flutter widget dependencies so it remains unit-testable via JUnit and `flutter test`.
- Follow the **Rule of 3** for UI widgets: extract repeated UI blocks only once used 3+ times, and prefer semantic named constructors (e.g., `Folder.root()`, `Folder.nested()`, `RecordingState.active()`).
