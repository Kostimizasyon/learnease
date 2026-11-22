import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learnese/data_models/audio_clip.dart';
import 'package:learnese/pages/library_page/player_sheet.dart';
import 'package:learnese/theme/app_theme.dart';

class _ControllableAudioPlayer implements ClipAudioPlayer {
  _ControllableAudioPlayer({this.throwOnLoad = false});

  final bool throwOnLoad;
  final _pos = StreamController<Duration>.broadcast(sync: true);
  final _dur = StreamController<Duration?>.broadcast(sync: true);
  final _playing = StreamController<bool>.broadcast(sync: true);

  bool playing = false;
  Duration lastSeek = Duration.zero;
  int playCalls = 0;
  int pauseCalls = 0;

  @override
  Stream<Duration> get positionStream => _pos.stream;

  @override
  Stream<Duration?> get durationStream => _dur.stream;

  @override
  Stream<bool> get playingStream => _playing.stream;

  @override
  Future<Duration?> setFilePath(String filePath) async {
    if (throwOnLoad) {
      throw Exception('File not found');
    }
    const dur = Duration(seconds: 20);
    _dur.add(dur);
    return dur;
  }

  @override
  Future<void> play() async {
    playCalls++;
    playing = true;
    _playing.add(true);
  }

  @override
  Future<void> pause() async {
    pauseCalls++;
    playing = false;
    _playing.add(false);
  }

  @override
  Future<void> seek(Duration position) async {
    lastSeek = position;
    _pos.add(position);
  }

  @override
  Future<void> dispose() async {
    await _pos.close();
    await _dur.close();
    await _playing.close();
  }
}

void main() {
  final sampleClip = AudioClip(
    id: 1,
    sessionId: 1,
    name: 'Key Phrase',
    filePath: '/clips/session_1/clip_1.wav',
    durationMs: 20000,
    sizeBytes: 1764044,
    createdAt: DateTime(2026, 6, 1),
  );

  group('PlayerSheet', () {
    testWidgets('plays, pauses, and skips forward/back via player controls', (
      WidgetTester tester,
    ) async {
      final player = _ControllableAudioPlayer();

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: PlayerSheet(
              clip: sampleClip,
              sessionName: 'Japanese Lesson',
              playerFactory: () => player,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Key Phrase'), findsOneWidget);
      expect(find.textContaining('Japanese Lesson'), findsOneWidget);
      expect(find.text('0:20'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.play_arrow_rounded));
      await tester.pumpAndSettle();
      expect(player.playCalls, 1);
      expect(find.byIcon(Icons.pause_rounded), findsOneWidget);

      await tester.tap(find.byTooltip('Forward 5 seconds'));
      await tester.pumpAndSettle();
      expect(player.lastSeek, const Duration(seconds: 5));

      await tester.tap(find.byTooltip('Back 5 seconds'));
      await tester.pumpAndSettle();
      expect(player.lastSeek, Duration.zero);

      await tester.tap(find.byIcon(Icons.pause_rounded));
      await tester.pumpAndSettle();
      expect(player.pauseCalls, 1);
      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
    });

    testWidgets('displays error message when audio file cannot be loaded', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: PlayerSheet(
              clip: sampleClip,
              playerFactory: () => _ControllableAudioPlayer(throwOnLoad: true),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Could not load audio file'), findsOneWidget);
      expect(find.byType(Slider), findsNothing);
    });

    testWidgets(
      'navigates next and previous clips within folder playlist and disables at bounds',
      (WidgetTester tester) async {
        final loadedPaths = <String>[];
        final player = _ControllableAudioPlayer();
        final clipA = AudioClip(
          id: 1,
          sessionId: 1,
          name: 'Folder Clip A',
          filePath: '/clips/folder/a.wav',
          durationMs: 10000,
          sizeBytes: 1000,
          createdAt: DateTime(2026, 6, 1),
        );
        final clipB = AudioClip(
          id: 2,
          sessionId: 1,
          name: 'Folder Clip B',
          filePath: '/clips/folder/b.wav',
          durationMs: 15000,
          sizeBytes: 2000,
          createdAt: DateTime(2026, 6, 1, 0, 1),
        );
        final clipC = AudioClip(
          id: 3,
          sessionId: 2,
          name: 'Folder Clip C',
          filePath: '/clips/folder/c.wav',
          durationMs: 20000,
          sizeBytes: 3000,
          createdAt: DateTime(2026, 6, 1, 0, 2),
        );

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light(),
            home: Scaffold(
              body: PlayerSheet(
                clip: clipA,
                sessionName: 'Session 1',
                playlist: <PlayableClip>[
                  PlayableClip(clip: clipA, sessionName: 'Session 1'),
                  PlayableClip(clip: clipB, sessionName: 'Session 1'),
                  PlayableClip(clip: clipC, sessionName: 'Session 2'),
                ],
                initialIndex: 0,
                playerFactory: () => _TrackingAudioPlayer(player, loadedPaths),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Folder Clip A'), findsOneWidget);
        expect(find.textContaining('1 / 3 in folder'), findsOneWidget);

        IconButton prevButton() => tester.widget<IconButton>(
          find.widgetWithIcon(IconButton, Icons.skip_previous_rounded),
        );
        IconButton nextButton() => tester.widget<IconButton>(
          find.widgetWithIcon(IconButton, Icons.skip_next_rounded),
        );

        expect(prevButton().onPressed, isNull);
        expect(nextButton().onPressed, isNotNull);

        // Step forward to B and C.
        await tester.tap(find.byTooltip('Next clip'));
        await tester.pumpAndSettle();
        expect(find.text('Folder Clip B'), findsOneWidget);
        expect(find.textContaining('2 / 3 in folder'), findsOneWidget);
        expect(prevButton().onPressed, isNotNull);
        expect(nextButton().onPressed, isNotNull);

        await tester.tap(find.byTooltip('Next clip'));
        await tester.pumpAndSettle();
        expect(find.text('Folder Clip C'), findsOneWidget);
        expect(find.textContaining('3 / 3 in folder'), findsOneWidget);
        expect(nextButton().onPressed, isNull);

        // Step backward to B.
        await tester.tap(find.byTooltip('Previous clip'));
        await tester.pumpAndSettle();
        expect(find.text('Folder Clip B'), findsOneWidget);
        expect(loadedPaths, <String>[
          '/clips/folder/a.wav',
          '/clips/folder/b.wav',
          '/clips/folder/c.wav',
          '/clips/folder/b.wav',
        ]);
      },
    );
  });
}

class _TrackingAudioPlayer implements ClipAudioPlayer {
  _TrackingAudioPlayer(this._inner, this._loadedPaths);

  final _ControllableAudioPlayer _inner;
  final List<String> _loadedPaths;

  @override
  Stream<Duration> get positionStream => _inner.positionStream;

  @override
  Stream<Duration?> get durationStream => _inner.durationStream;

  @override
  Stream<bool> get playingStream => _inner.playingStream;

  @override
  Future<Duration?> setFilePath(String filePath) {
    _loadedPaths.add(filePath);
    return _inner.setFilePath(filePath);
  }

  @override
  Future<void> play() => _inner.play();

  @override
  Future<void> pause() => _inner.pause();

  @override
  Future<void> seek(Duration position) => _inner.seek(position);

  @override
  Future<void> dispose() => _inner.dispose();
}
