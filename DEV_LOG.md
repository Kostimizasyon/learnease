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

### Open Questions (for Developer before Chunk 3)
1. **Output format — AAC `.m4a` vs uncompressed PCM `.wav`**: The spec mentions *"Encode to AAC (`.wav`) with `MediaCodec` + `MediaMuxer` to keep files small"* (Section 2) and *"encodes it to a new `.wav`"* (Section 3.2). Android's `MediaMuxer` cannot write `.wav` containers — AAC + `MediaMuxer` produces **`.m4a`** (MPEG-4 audio, ~480 KB for 30s at 128 kbps), whereas **`.wav`** is raw PCM (~2.5 MB for 30s mono, instant write, no `MediaCodec` needed). Which do you prefer for Chunk 3: **AAC in `.m4a`** (small files via `MediaCodec` + `MediaMuxer`) or **PCM `.wav`**?
2. **Channel count**: Is **44.1 kHz 16-bit mono** (~15.1 MiB max buffer) good for your primary use case, or would you prefer **stereo** (~30.3 MiB max buffer) for music?
