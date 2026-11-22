# Learnese Dev Log

Append-only log of architecture decisions, trade-offs, assumptions, and open questions per chunk.

---

## 2026-11-22 — Chunk 1: Repo, Project Setup, Theme, Models & Docs

### Decisions Made
- **Android-only scaffold**: Created with `flutter create --platforms=android`, configured `applicationId` and `namespace` to `com.learnese.app`, `minSdk = 29` (first API supporting `AudioPlaybackCaptureConfiguration`), and `android:label="Learnese"`. Removed default `cupertino_icons` dependency since iOS is out of scope.
- **Packages configured in `pubspec.yaml`**: Added only the approved spec packages (`sqflite`, `path`, `path_provider`, `shared_preferences`, `permission_handler`, `just_audio`, plus dev packages `flutter_launcher_icons`, `sqflite_common_ffi`, `mocktail`, and template `flutter_lints`). No extra dependencies added.
- **Rolling buffer design & memory math**:
  - Capture format candidate: **16-bit PCM (`ENCODING_PCM_16BIT`, 2 bytes/sample) at 44,100 Hz**.
  - **Mono (1 channel)** = `44,100 * 2 = 88,200 B/s` (~86.1 KiB/s):
    - `15s`: ~1.26 MiB | `30s`: ~2.52 MiB | `60s`: ~5.05 MiB | `120s`: ~10.09 MiB | `180s` (hard cap): **~15.14 MiB**.
  - **Stereo (2 channels)** = `44,100 * 2 * 2 = 176,400 B/s` (~172.3 KiB/s):
    - `15s`: ~2.52 MiB | `30s`: ~5.05 MiB | `60s`: ~10.09 MiB | `120s`: ~20.19 MiB | `180s` (hard cap): **~30.28 MiB**.
  - **Peak RAM during save**: Snapshotting the ring buffer onto an encoding worker temporarily allocates a second buffer copy (`~30.3 MiB` peak at 180s mono, `~60.6 MiB` peak at 180s stereo). Defaulting to **44.1 kHz 16-bit mono** keeps peak memory safe on low-RAM Android devices while preserving full speech clarity for language/learning audio.
- **Fixed X per session**: Buffer length `X` (`1..180s`, presets `[15, 30, 60, 120]`, default `30s`) is validated on session creation and remains fixed for the session's lifetime — avoiding live ring-buffer reallocation and race conditions while capturing. No auto-stop or session timer.
- **Timestamps as Unix epoch milliseconds**: All SQLite date columns (`started_at`, `ended_at`, `created_at`) serialize as `int` epoch ms, and `.create()` / `.root()` / `.nested()` truncate default `DateTime.now()` to millisecond precision so `fromMap(model.toMap()) == model` holds reliably.
- **Color palette & ThemeExtension**: Picked deep teal (`#0F766E` light / `#2DD4BF` dark) + neutral slate surfaces (`#F8FAFC`/`#FFFFFF` light, `#0B1115`/`#131C22` dark) + red (`#DC2626`/`#F87171`) reserved strictly for live recording and destructive/dismiss states via `AppRecordingColors`. Mirrored overlay tokens in `android/app/src/main/res/values/colors.xml`.

### Alternatives Rejected
- **Disk-backed rolling buffer**: Rejected because unsaved audio must never touch disk (privacy + flash wear + latency).
- **Heavy state management (Riverpod/BLoC)**: Rejected per spec; simple `ChangeNotifier` / `ValueNotifier` + `ListenableBuilder` fits the small screen surface.
- **Flutter-side overlay widget plugin**: Rejected per spec; native `WindowManager` overlay hosted inside `RecordingService` avoids spinning up a second Flutter engine and keeps overlay lifetime strictly bound to the recording service.

### Problems Hit
- `flutter create --org com.learnese --project-name learnese` generated `com.learnese.learnese` as the Android application ID and Kotlin package path. Fixed immediately by updating `build.gradle.kts` to `com.learnese.app`, moving `MainActivity.kt` to `kotlin/com/learnese/app/`, and deleting the old folder.

### Open Questions (Resolved)
1. **Output format**: Locked in **44.1 kHz 16-bit mono `.wav`** (44-byte RIFF header + raw PCM) instead of AAC `.m4a` (`MediaCodec`/`MediaMuxer`). Reasoning: near-instant saves, zero OEM `MediaCodec` quirks, lossless quality for language/study tooling, and pure-Kotlin unit-testability. Storage cost (~86.1 KiB/s, ~2.52 MiB per 30s) is acceptable.
2. **Channel count**: **Mono (1 channel)** confirmed (~15.14 MiB max ring buffer at 180s).

---

## 2026-11-22 — Chunk 2: Database, Repositories & Storage

### Decisions Made
- **Folder deletion cascade policy**: Configured `folders.parent_id` with `ON DELETE CASCADE` (deleting a folder deletes its sub-folders) and `sessions.folder_id` with `ON DELETE SET NULL` (sessions inside deleted folders return to root instead of silently losing user audio recordings). Enabled `PRAGMA foreign_keys = ON` in `DatabaseHelper._onConfigure`.
- **Cycle prevention in `FolderRepository.moveFolder`**: Walks `getBreadcrumbs(newParentId)` before updating `parent_id` to reject moving a folder into itself or any descendant.
- **Testability without platform channels**: `DatabaseHelper` accepts an injectable `DatabaseFactory` + `dbPath` (`sqflite_common_ffi` + `inMemoryDatabasePath` in tests), and `StorageService` accepts an injectable `rootDirectoryProvider` (`Directory.systemTemp` in tests).
- **Clip file layout**: `clips/session_<sessionId>/clip_<epochMs>.wav` with millisecond collision suffixing so rapid repeated saves never overwrite each other.

### Alternatives Rejected
- **`ON DELETE CASCADE` on `sessions.folder_id`**: Rejected because accidentally deleting an organization folder should not destroy recorded audio sessions and `.wav` files; `SET NULL` is safer and reversible.
- **Singleton-only `DatabaseHelper`**: Rejected in favor of an injectable constructor so `sqflite_common_ffi` tests stay isolated in memory.

### Post-Review Hardening (Chunk 2)
- Deduplicated concurrent `DatabaseHelper.database` opens via an in-flight `_opening` future and added SQLite `CHECK` constraints (`buffer_seconds BETWEEN 1 AND 180`, `duration_ms >= 0`, `size_bytes >= 0`).
- Added `ArgumentError` guards for conflicting `rootOnly: true` + `folderId`/`parentId` filters, empty-path guard in `StorageService.fileSizeBytes()`, and `PathNotFoundException` handling on file/directory deletes.
- Expanded `sqflite_common_ffi` tests to verify concurrent DB open, CHECK/FK violations, 3-level folder cascade deletes, `newestFirst` clip ordering, direct session directory removal, and lower-bound preference clamping.
- Noted for Chunk 3: pass Dart's `StorageService.getSessionDirectory(sessionId)` path to Kotlin on `startSession` so Kotlin writes clips into the exact same directory Dart manages (`app_flutter/clips/...` vs `files/`).

---

## 2026-11-22 — Chunk 3: Native Recording Core

### Decisions Made
- **Pure Kotlin extraction (`AudioRingBuffer.kt`)**: Adjusted Section 5 layout slightly by placing pure JVM classes (`AudioFormatSpec`, `AudioRingBuffer`, `WavWriter`, `ClipFileNamer`) in their own file `AudioRingBuffer.kt` with zero Android imports so Gradle JUnit tests verify wrap-around ordering, partial-fill snapshots, 44-byte RIFF/WAVE headers, and collision-safe clip naming without Android mocks.
- **Android 14+ foreground service ordering**: `RecordingService.handleStartSession` calls `ServiceCompat.startForeground(..., FOREGROUND_SERVICE_TYPE_MEDIA_PROJECTION)` *before* `MediaProjectionManager.getMediaProjection()` and registers a `MediaProjection.Callback` *before* starting `AudioRecord`, avoiding Android 14+ `SecurityException` / `IllegalStateException` crashes and handling system revocation (`projection_revoked`).
- **Atomic `.wav` writes & stop-flush semantics**: `WavWriter.writePcmToWav` writes to a sibling `.tmp` file, calls `fd.sync()`, and atomically renames to `.wav`. On `stopSession()`, `AudioCaptureEngine.stopAndFlush` immediately halts capture and zeroes the RAM ring buffer, then shuts down and awaits `saveExecutor` termination on a background thread so any save already in flight finishes and flushes before the service terminates.
- **Channel & permission testability**: `RecorderChannel` accepts injectable `MethodChannel`/`EventChannel` instances; `PermissionService` delegates through an injectable `PermissionGateway` interface so all permission states can be unit-tested via `mocktail`.

### Alternatives Rejected
- **Using `ActivityResultContracts` in `MainActivity`**: Standard `FlutterActivity` extends `android.app.Activity` (not `ComponentActivity`), so `onActivityResult` is used cleanly without forcing `FlutterFragmentActivity`.
- **Reusing `MediaProjection` across sessions**: Disallowed on Android 14+; `MainActivity` always launches fresh consent per session.

### Problems Hit (Chunk 3)
- `permission_handler_android` (`14.1.1`) required `compileSdk >= 37` while Flutter's default was `36`. Updated `compileSdk = 37` in `android/app/build.gradle.kts` (`android-37.0` SDK is installed locally).
- `finalizeStop` lambda in `RecordingService.kt` inferred `() -> Boolean` from `Handler.post`; annotated explicitly as `() -> Unit`.

---

## 2026-11-22 — Chunk 4: Overlay Button

### Decisions Made
- **Pure Kotlin geometry extraction (`OverlayGeometry.kt`)**: Adjusted Section 5 layout slightly by extracting edge-snap, vertical inset clamping, dismiss-zone hit detection, tap-slop detection, and `TapDebouncer` (250ms debounce) into `OverlayGeometry.kt` (zero Android imports) so all overlay physics and debounce behavior are verified via JUnit (`OverlayGeometryTest.kt`).
- **Strict overlay = session lifetime**: Both `MainActivity.handleStartSessionCall` and `RecordingService.handleStartSession` enforce `Settings.canDrawOverlays`, so a session cannot run headless without the floating button. Dropping the 52dp bubble onto the bottom X dismiss target immediately hides the overlay and routes through `RecordingService.stopSessionInternal()` (identical to notification Stop and in-app Stop), flushing any in-flight `.wav` write before terminating the service.
- **Rotation resilience & foreground-service ordering**: `RecordingService.onConfigurationChanged` calls `overlayController.reclampToScreen()` so landscape/portrait rotations keep the bubble snapped on-screen. The service-side `canDrawOverlays` defense-in-depth check runs *after* `ServiceCompat.startForeground()` to prevent `ForegroundServiceDidNotStartInTimeException` on Android 12+.
- **Direct overlay settings flow**: Added `hasOverlayPermission` / `openOverlayPermissionSettings` (`ACTION_MANAGE_OVERLAY_PERMISSION` targeting `package:com.learnese.app`) to `MainActivity` + `RecorderChannel`, and built `PermissionGate` (`PermissionGate.sessionSetup()`, `PermissionGate.overlayOnly()`) with `WidgetsBindingObserver` resume refresh.

### Alternatives Rejected
- **Using a Flutter overlay engine plugin**: Rejected per spec to avoid a second Flutter engine's memory overhead and keep overlay lifetime locked to `RecordingService`.
- **Generic `openAppSettings()` for overlay permission**: Rejected in favor of Android's direct `ACTION_MANAGE_OVERLAY_PERMISSION` deep link so users land directly on Learnese's overlay toggle.

---

## 2026-11-22 — Chunk 5: Home Flow & Active Session UI

### Decisions Made
- **Added `lib/services/session_controller.dart`**: Adjusted Section 5 layout by introducing a dedicated `ChangeNotifier` coordinator rather than burying SQLite + EventChannel orchestration inside widget `State` classes. Keeps UI widgets thin and allows deterministic unit tests (`session_controller_test.dart`) with `sqflite_common_ffi` + mocked `RecorderChannel`.
- **Sequential event queue & clip deduplication**: `SessionController` serializes incoming `EventChannel` events through `_eventQueue` and tracks `_persistedClipPaths` so replayed state snapshots or dual MethodChannel/EventChannel callbacks never double-insert clips into SQLite.
- **Consent rollback & orphan reconciliation**: Cancelling `MediaProjection` deletes the newly created empty DB session row so cancelled attempts never clutter the Library. On startup, if SQLite has an un-ended session while native reports `idle`, `initialize()` automatically closes it.
- **Tab-driven Active Session routing**: `HomePage` renders `ActiveSessionPage` directly whenever `controller.isSessionActive` is true, so notification taps (`onOpenActiveSession` / `consumeOpenActiveSession`) simply switch the root `NavigationBar` to tab `0` with zero stale navigator stack edge cases.
- **In-app honesty**: Added a concise disclosure card on `HomePage` explaining output-only capture, RAM-only buffer, continuous battery/RAM cost & Android indicator, and third-party app opt-outs / DRM silence.

---

## 2026-11-22 — Chunk 6: Library, Rename, Folders & Playback

### Decisions Made
- **Added `lib/services/library_controller.dart`**: Mirrors `SessionController`'s thin `ChangeNotifier` pattern (adjusted Section 5 layout and logged in `project-structure.md`), keeping SQLite orchestration, breadcrumb state, descendant-exclusion math for moves, and automatic refresh-on-clip-save cleanly testable via `sqflite_common_ffi`.
- **`ClipAudioPlayer` abstraction for `just_audio`**: `PlayerSheet` delegates to `JustAudioClipPlayer` by default and accepts an optional `ClipPlayerFactory` so widget tests verify play/pause, seek/skip, and missing-file errors without requiring Android ExoPlayer.
- **`FolderMoveSelection` wrapper in `AppDialog.pickFolder`**: Distinguishes selecting "Library (Root)" (`FolderMoveSelection.root()`) from cancelling the dialog (`null`) cleanly without sentinel integers.
- **Stateful text-input dialogs**: `_TextInputDialog` owns and disposes its `TextEditingController` in `State.dispose()` so closing dialogs never hits Flutter's exit-animation controller-disposed race.

---

## 2026-11-22 — Chunk 7: App Icon, Polish & Release Readiness

### Decisions Made
- **Original Learnese icon (`assets/icon/`)**: Designed a crisp circular counter-clockwise instant-replay arrow enclosing three centered audio waveform bars on the Deep Teal (`#0F766E`) primary surface (`#FFFFFF` arc/center bar, `#CCFBF1` side bars). Generated vector source (`learnese_icon.svg`) and 2x2 supersampled 1024×1024 PNGs (`icon_full.png`, `icon_foreground.png`, `icon_monochrome.png`), wired through `flutter_launcher_icons` to produce Android adaptive icons (`mipmap-anydpi-v26/ic_launcher.xml` with background, foreground, and Android 13+ monochrome layers) and legacy mipmaps.
- **Low-storage & OOM resilience**: Added `InsufficientStorageException` and `WavWriter.hasEnoughStorage()` (requiring header + PCM + 1 MiB safety margin) mapped to `CaptureError.storageError`, plus `OutOfMemoryError` guards around `AudioRingBuffer` allocation and snapshot copy in `AudioCaptureEngine`.
- **Mid-session revocation & OS kill recovery**: `RecordingService` verifies `Settings.canDrawOverlays` on periodic progress ticks and checks `RECORD_AUDIO` on fatal `AudioRecord` read failures to report exact revocation errors. `LearneseApp` mixes in `WidgetsBindingObserver` and calls `SessionController.syncWithNative()` on `AppLifecycleState.resumed` to reconcile sessions if Android kills the foreground service in the background.
- **UI polish**: Added `"Waiting for device audio output…"` state on `ActiveSessionPage` while buffer is at `0ms`, and added a **Retry** button on `LibraryPage` error banners.
- **Manual QA checklist**: Documented an end-to-end physical-device QA checklist in `README.md`.

---

## 2026-11-22 — Folder-Scoped Next/Previous Playback & Release APK Workflow

### Decisions Made
- **Folder-scoped playlist (`LibraryController.currentFolderPlayableClips`)**: Flattens clips only across `sessions` belonging to `_currentFolderId` (excluding parent, sibling, and sub-folder clips). Passed into `PlayerSheet` so Previous/Next buttons never cross folder boundaries.
- **Resilient track switching**: `PlayerSheet._selectIndex` increments `_loadEpoch` to ignore stale async `setFilePath` completions and keeps Previous/Next buttons available on error cards so a missing file never traps navigation.

---

## 2026-11-22 — Clear Rolling Buffer on Every Clip Save

### Decisions Made
- **Atomic `AudioRingBuffer.snapshotAndClear()`**: Replaced `buffer.snapshot()` in `AudioCaptureEngine.saveClip()` with a synchronized `snapshotAndClear()` so extracting PCM and resetting/zeroing the ring buffer happen under one lock (no dropped frames between snapshot and clear, and zero audio overlap across consecutive saved clips).
- **Immediate UI reset**: `AudioCaptureEngine.saveClip()` invokes `bufferedUpdateCallback(0L)` right after clearing so `ActiveSessionPage`'s buffer progress indicator resets to `0s` immediately while `.wav` writing runs asynchronously.

---

## 2026-11-22 — Home UI Refresh, Updated Buffer Presets, Modern Dialogs & `S-DD:MM:YY` Naming

### Decisions Made
- **Decluttered Home Screen**: Replaced stacked explanatory cards with a spacious, centered hero layout (tonal audio emblem, bold `${X}s` readout, flat stadium-pill `BufferLengthPicker`, stadium `RecordButton`, and a compact footer/AppBar info trigger opening the full playback-capture disclosure bottom sheet).
- **Updated Presets**: Changed `RecordingSession.presetBufferSeconds` to `[5, 10, 15, 30, 60]` (keeping `1..180s` custom cap).
- **Modern Alert Dialogs**: Added rounded 24dp `DialogThemeData`, circular tonal icon badges, centered headings/subtitles, rounded selectable folder rows in `AppDialog.pickFolder`, and full-width split Cancel/Confirm buttons across `AppDialog` and `_CustomBufferDialog`.
- **Compact Session Naming (`S-DD:MM:YY`)**: Updated `RecordingSession.defaultName()` to zero-padded `S-DD:MM:YY` (2-digit day, month, and year) and surfaced `HH:mm` start time in `SessionTile`'s subtitle for easy same-day differentiation.

---

## 2026-11-22 — Comic Sans Typography, AppBar Removal & Floating Pill Navigation Bar

### Decisions Made
- **Bundled `ComicSans` font**: Copied `comic.ttf` and `comicbd.ttf` into `assets/fonts/` and registered `ComicSans` in `pubspec.yaml` + `AppTheme` so the font renders reliably offline on Android without needing `INTERNET` permission (note: swap to an SIL OFL alternative such as Comic Neue before any public store release).
- **Removed AppBars**: Removed `AppBar` and unused `custom_app_bar.dart` across `HomePage`, `ActiveSessionPage`, and `LibraryPage`, replacing them with clean inline `SafeArea` headers/actions.
- **Floating Pill Navigation Bar**: Replaced full-width `NavigationBar` with `FloatingPillNavBar` (`extendBody: true` + bottom scroll padding `96dp`), keeping both icons and page names (`Record` / `Active`, `Library`).
