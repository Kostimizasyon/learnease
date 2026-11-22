# Project Structure

## Goal

Build **Learnese** (`com.learnese.app`), an Android-only Flutter + Kotlin audio instant-replay app that keeps a rolling in-memory buffer of the last **X** seconds of device audio output and saves clips on demand via a floating overlay button, organized by session and nested folders.

## File Breakdown

### Root, Assets & Documentation
- `pubspec.yaml` — Package manifest, dependencies (`sqflite`, `path`, `path_provider`, `shared_preferences`, `permission_handler`, `just_audio`), dev/test tools (`sqflite_common_ffi`, `mocktail`, `flutter_launcher_icons`, `flutter_lints`), and adaptive icon config.
- `assets/icon/` — Original Learnese icon master (`learnese_icon.svg`) and 1024×1024 PNG sources (`icon_full.png`, `icon_foreground.png`, `icon_monochrome.png`) wired to `flutter_launcher_icons`.
- `analysis_options.yaml` — Strict Dart analyzer settings (`strict-casts`, `strict-inference`, `strict-raw-types`) and `flutter_lints` rules.
- `.gitignore` — Excludes Flutter/Android build outputs, IDE files, `.env`, and signing keystores.
- `README.md` — Product overview, requirements, build/test commands, permissions, and Android platform limitations.
- `project-structure.md` — This file: directory map and chunk progress tracker.
- `CODE_GUIDE.md` — Architecture, Dart <-> Kotlin bridge contract, lifecycle, and contributor guide.
- `DEV_LOG.md` — Append-only chronological engineering log of decisions, math, and open questions.

### Android Native (`android/`)
- `android/app/build.gradle.kts` — Android app config (`com.learnese.app`, `minSdk = 29`, `compileSdk = 37`, Java/Kotlin 17, `androidx.core:core-ktx`, `junit`).
- `android/app/src/main/AndroidManifest.xml` — Declares the 5 required permissions (`RECORD_AUDIO`, `FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_MEDIA_PROJECTION`, `POST_NOTIFICATIONS`, `SYSTEM_ALERT_WINDOW`) and `RecordingService` (`foregroundServiceType="mediaProjection"`, `exported="false"`).
- `android/app/src/main/res/values/colors.xml` — Native color tokens mirroring `lib/theme/app_colors.dart` for the overlay and notification.
- `android/app/src/main/res/drawable/ic_stat_learnese.xml` — Monochrome waveform status-bar icon for the ongoing recording notification.
- `android/app/src/main/res/drawable/ic_overlay_save.xml` — Replay-capture vector icon for the floating overlay button.
- `android/app/src/main/res/drawable/ic_overlay_check.xml` — Brief checkmark vector icon shown on the overlay after a clip saves.
- `android/app/src/main/res/drawable/ic_overlay_dismiss.xml` — Close (`X`) vector icon for the drag-to-dismiss target.
- `android/app/src/main/kotlin/com/learnese/app/MainActivity.kt` — Registers `MethodChannel`/`EventChannel`, checks audio + overlay permissions, opens Android's overlay settings, runs per-session `MediaProjection` consent, and forwards notification tap deep links.
- `android/app/src/main/kotlin/com/learnese/app/RecordingService.kt` — Foreground service owning `MediaProjection`, `AudioCaptureEngine`, `OverlayController`, ongoing notification, and `RecordingSessionBus`.
- `android/app/src/main/kotlin/com/learnese/app/OverlayController.kt` — Native `TYPE_APPLICATION_OVERLAY` 52dp floating button (draggable, edge-snapping, pulsing recording dot, debounced tap-to-save with teal check flash, bottom X dismiss target ending the session, rotation re-clamping).
- `android/app/src/main/kotlin/com/learnese/app/OverlayGeometry.kt` — Pure JVM overlay edge-snap, Y-clamp, dismiss-zone hit test, tap-slop check, and `TapDebouncer` for JUnit testing.
- `android/app/src/main/kotlin/com/learnese/app/AudioCaptureEngine.kt` — `AudioPlaybackCaptureConfiguration` + `AudioRecord` (internal playback only, never mic) feeding `AudioRingBuffer` and flushing `.wav` snapshots on a background thread.
- `android/app/src/main/kotlin/com/learnese/app/AudioRingBuffer.kt` — Pure JVM classes (`AudioFormatSpec`, `AudioRingBuffer`, `WavWriter`, `ClipFileNamer`) kept free of Android SDK imports for JUnit testing.
- `android/app/src/main/kotlin/com/learnese/app/NotificationFactory.kt` — Low-importance notification channel, ongoing notification builder, active-session tap intent, and Stop Session action.
- `android/app/src/test/kotlin/com/learnese/app/AudioRingBufferTest.kt` — JUnit tests for ring-buffer wrap-around/partial-fill/clear, 44-byte RIFF/WAVE header generation, and collision-safe clip naming.
- `android/app/src/test/kotlin/com/learnese/app/OverlayGeometryTest.kt` — JUnit tests for edge snapping, Y-inset clamping, dismiss hit area, tap vs drag detection, and `TapDebouncer`.

### Flutter App (`lib/`)
- `lib/main.dart` — App entry point (`LearneseApp`) wiring services, `SessionController`, notification-tap tab routing, light/dark themes, and Record/Library navigation.
- `lib/theme/app_colors.dart` — Centralized color palette (deep teal primary, neutral slate surfaces, red reserved for recording/destructive state, overlay tokens).
- `lib/theme/app_theme.dart` — Material 3 `AppTheme.light()` / `AppTheme.dark()` and `AppRecordingColors` `ThemeExtension`.
- `lib/data_models/recording_session.dart` — `RecordingSession` entity (`sessions` table), buffer bounds (`1..180s`), default naming (`Session YYYY-MM-DD HH:mm`), and serialization.
- `lib/data_models/audio_clip.dart` — `AudioClip` entity (`clips` table), default naming (`Clip N`), and serialization.
- `lib/data_models/folder.dart` — `Folder` entity (`folders` table) with `Folder.root()` / `Folder.nested()` named constructors and serialization.
- `lib/data_models/recording_state.dart` — `SessionStatus`, `CaptureError`, and `RecordingState` EventChannel payload model.
- `lib/services/database_helper.dart` — SQLite lifecycle, `PRAGMA foreign_keys = ON`, versioned migrations, and schema/indexes for `folders`, `sessions`, and `clips`.
- `lib/services/session_repository.dart` — CRUD for `RecordingSession` and `AudioClip`, newest-first session queries, and disk file cleanup on delete.
- `lib/services/folder_repository.dart` — CRUD for `Folder`, alphabetical listing, breadcrumb ancestor resolution, and cycle-safe folder moves.
- `lib/services/storage_service.dart` — App-specific `.wav` clip paths (`clips/session_<id>/clip_<ts>.wav`), size queries, and file/directory deletion.
- `lib/services/preferences_service.dart` — `SharedPreferences` wrapper for last buffer length (`1..180s`) and onboarding hint flags.
- `lib/services/recorder_channel.dart` — `MethodChannel`/`EventChannel` wrapper (`startSession`, `saveClip`, `stopSession`, `getState`, `hasOverlayPermission`, `openOverlayPermissionSettings`, `stateStream`, notification deep-link hooks).
- `lib/services/permission_service.dart` — Testable runtime permission wrapper (`RECORD_AUDIO`, `POST_NOTIFICATIONS`, `SYSTEM_ALERT_WINDOW`) with `PermissionGateway`.
- `lib/services/session_controller.dart` — `ChangeNotifier` orchestrating session start/stop, native event stream ingestion, clip DB persistence with deduplication, stale-session reconciliation, and notification deep-link callbacks.
- `lib/services/library_controller.dart` — `ChangeNotifier` coordinating folder browsing, breadcrumbs, cycle-safe move targets, session/clip/folder CRUD, and live refresh on session changes.
- `lib/pages/util/app_dialog.dart` — Reusable dialogs with semantic named constructors (`AppDialog.rename()`, `AppDialog.createFolder()`, `AppDialog.confirmDelete()`, `AppDialog.pickFolder()`).
- `lib/pages/util/custom_app_bar.dart` — `CustomAppBar.standard()` and `CustomAppBar.recording()` with live recording dot indicator.
- `lib/pages/util/permission_gate.dart` — Reusable permission setup widget (`PermissionGate.sessionSetup()`, `PermissionGate.overlayOnly()`) with lifecycle-resume re-check after returning from Android overlay Settings.
- `lib/pages/home_page/util/buffer_length_picker.dart` — `BufferLengthChip.preset()`, `BufferLengthChip.custom()`, and `BufferLengthPicker` (15/30/60/120s + custom 1–180s dialog + RAM estimate).
- `lib/pages/home_page/util/record_button.dart` — `RecordButton.start()` and `RecordButton.stop()`.
- `lib/pages/home_page/home_page.dart` — Idle recording setup screen (buffer length picker, Record Now, permission gate dialog, honest playback capture disclosure) transitioning seamlessly to `ActiveSessionPage`.
- `lib/pages/home_page/active_session_page.dart` — Live recording session screen (buffer length X badge, rolling fill bar, clip count, Save Now, Stop Session, Open Library).
- `lib/pages/library_page/util/folder_tile.dart` — `FolderTile.root()` and `FolderTile.nested()` with rename/move/delete actions.
- `lib/pages/library_page/util/session_tile.dart` — Expandable `SessionTile.active()` and `SessionTile.completed()` grouping clips by session.
- `lib/pages/library_page/util/clip_tile.dart` — `ClipTile.standard()` and `ClipTile.compact()` with duration/size formatting, play trigger, and rename/delete menu.
- `lib/pages/library_page/player_sheet.dart` — Bottom-sheet audio player (`just_audio` behind testable `ClipAudioPlayer`) with play/pause, seek slider, ±5s skip, and missing-file error handling.
- `lib/pages/library_page/library_page.dart` — Sessions & folders browser with breadcrumb navigation, create/rename/move/delete flows, and clip playback.

### Tests (`test/`)
- `test/data_models/recording_session_test.dart` — Unit tests for `RecordingSession`.
- `test/data_models/audio_clip_test.dart` — Unit tests for `AudioClip`.
- `test/data_models/folder_test.dart` — Unit tests for `Folder`.
- `test/data_models/recording_state_test.dart` — Unit tests for `RecordingState` and wire parsing.
- `test/theme/app_theme_test.dart` — Unit tests for light/dark themes and `AppRecordingColors`.
- `test/services/database_helper_test.dart` — `sqflite_common_ffi` tests for schema creation, foreign keys, concurrent opens, and CHECK constraints.
- `test/services/session_repository_test.dart` — `sqflite_common_ffi` tests for session/clip CRUD, cascade deletes, and `.wav` file cleanup.
- `test/services/folder_repository_test.dart` — `sqflite_common_ffi` tests for nested folders, breadcrumbs, cycle prevention, and cascade rules.
- `test/services/storage_service_test.dart` — Unit tests for unique clip paths, file sizes, and directory cleanup.
- `test/services/preferences_service_test.dart` — Unit tests for `PreferencesService` with mock `SharedPreferences`.
- `test/services/recorder_channel_test.dart` — Mocked `MethodChannel`/`EventChannel` tests for `RecorderChannel`.
- `test/services/permission_service_test.dart` — `mocktail` tests for `PermissionService`.
- `test/services/session_controller_test.dart` — Unit tests for `SessionController` lifecycle, clip persistence/dedup, consent cancellation rollback, and orphan reconciliation.
- `test/services/library_controller_test.dart` — `sqflite_common_ffi` repository-integration tests for `LibraryController` nested folders, breadcrumbs, moves, renames, and disk-cleaning deletes.
- `test/pages/util/permission_gate_test.dart` — Widget tests for `PermissionGate` permission flow and lifecycle-resume refresh.
- `test/pages/home_page/buffer_length_picker_test.dart` — Widget tests for preset chips and custom 1–180s validation dialog.
- `test/pages/home_page/home_and_active_session_test.dart` — End-to-end widget test for Home -> ActiveSession transitions, clip count updates, notification tap routing, and Stop Session.
- `test/pages/library_page/library_page_test.dart` — Widget tests for Library browsing, folder creation, breadcrumbs, rename/move/delete dialogs, and playback sheet trigger.
- `test/pages/library_page/player_sheet_test.dart` — Widget tests for `PlayerSheet` play/pause, seek/skip controls, and missing-file error UI.
- `test/widget_test.dart` — Widget test verifying `LearneseApp` theme and navigation wiring.

## Chunk Status

- [x] **Chunk 1**: Repo, Project Setup, Theme, Models & Docs
- [x] **Chunk 2**: Database, Repositories & Storage
- [x] **Chunk 3**: Native Recording Core
- [x] **Chunk 4**: Overlay Button
- [x] **Chunk 5**: Home Flow & Active Session UI
- [x] **Chunk 6**: Library, Rename, Folders & Playback
- [x] **Chunk 7**: App Icon, Polish & Release Readiness
