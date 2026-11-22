# Project Structure

## Goal

Build **Learnese** (`com.learnese.app`), an Android-only Flutter + Kotlin audio instant-replay app that keeps a rolling in-memory buffer of the last **X** seconds of device audio output and saves clips on demand via a floating overlay button, organized by session and nested folders.

## File Breakdown

### Root & Documentation
- `pubspec.yaml` — Package manifest, dependencies (`sqflite`, `path`, `path_provider`, `shared_preferences`, `permission_handler`, `just_audio`), and dev/test tools (`sqflite_common_ffi`, `mocktail`, `flutter_launcher_icons`, `flutter_lints`).
- `analysis_options.yaml` — Strict Dart analyzer settings (`strict-casts`, `strict-inference`, `strict-raw-types`) and `flutter_lints` rules.
- `.gitignore` — Excludes Flutter/Android build outputs, IDE files, `.env`, and signing keystores.
- `README.md` — Product overview, requirements, build/test commands, permissions, and Android platform limitations.
- `project-structure.md` — This file: directory map and chunk progress tracker.
- `CODE_GUIDE.md` — Architecture, Dart <-> Kotlin bridge contract, lifecycle, and contributor guide.
- `DEV_LOG.md` — Append-only chronological engineering log of decisions, math, and open questions.

### Android Native (`android/`)
- `android/app/build.gradle.kts` — Android app config (`com.learnese.app`, `minSdk = 29`, Java/Kotlin 17).
- `android/app/src/main/AndroidManifest.xml` — App entry point (`Learnese`); recording permissions and foreground service added in Chunk 3.
- `android/app/src/main/kotlin/com/learnese/app/MainActivity.kt` — Flutter host activity (platform channels and projection consent added in Chunk 3).
- `android/app/src/main/res/values/colors.xml` — Native color tokens mirroring `lib/theme/app_colors.dart` for the overlay and notification.

### Flutter App (`lib/`)
- `lib/main.dart` — App entry point (`LearneseApp`) wired to light/dark themes and a temporary bootstrap shell.
- `lib/theme/app_colors.dart` — Centralized color palette (deep teal primary, neutral slate surfaces, red reserved for recording/destructive state, overlay tokens).
- `lib/theme/app_theme.dart` — Material 3 `AppTheme.light()` / `AppTheme.dark()` and `AppRecordingColors` `ThemeExtension`.
- `lib/data_models/recording_session.dart` — `RecordingSession` entity (`sessions` table), buffer bounds (`1..180s`), default naming (`Session YYYY-MM-DD HH:mm`), and serialization.
- `lib/data_models/audio_clip.dart` — `AudioClip` entity (`clips` table), default naming (`Clip N`), and serialization.
- `lib/data_models/folder.dart` — `Folder` entity (`folders` table) with `Folder.root()` / `Folder.nested()` named constructors and serialization.
- `lib/data_models/recording_state.dart` — `SessionStatus`, `CaptureError`, and `RecordingState` EventChannel payload model.

### Tests (`test/`)
- `test/data_models/recording_session_test.dart` — Unit tests for `RecordingSession`.
- `test/data_models/audio_clip_test.dart` — Unit tests for `AudioClip`.
- `test/data_models/folder_test.dart` — Unit tests for `Folder`.
- `test/data_models/recording_state_test.dart` — Unit tests for `RecordingState` and wire parsing.
- `test/theme/app_theme_test.dart` — Unit tests for light/dark themes and `AppRecordingColors`.
- `test/widget_test.dart` — Widget test verifying `LearneseApp` bootstrap and theme setup.

## Chunk Status

- [x] **Chunk 1**: Repo, Project Setup, Theme, Models & Docs
- [ ] **Chunk 2**: Database, Repositories & Storage
- [ ] **Chunk 3**: Native Recording Core
- [ ] **Chunk 4**: Overlay Button
- [ ] **Chunk 5**: Home Flow & Active Session UI
- [ ] **Chunk 6**: Library, Rename, Folders & Playback
- [ ] **Chunk 7**: App Icon, Polish & Release Readiness
