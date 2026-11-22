import 'dart:async';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import '../../data_models/audio_clip.dart';
import 'util/clip_tile.dart';

/// Thin abstraction over `just_audio`'s [AudioPlayer] so playback UI is widget-testable.
abstract class ClipAudioPlayer {
  Stream<Duration> get positionStream;
  Stream<Duration?> get durationStream;
  Stream<bool> get playingStream;

  Future<Duration?> setFilePath(String filePath);
  Future<void> play();
  Future<void> pause();
  Future<void> seek(Duration position);
  Future<void> dispose();
}

class JustAudioClipPlayer implements ClipAudioPlayer {
  JustAudioClipPlayer() : _player = AudioPlayer();

  final AudioPlayer _player;

  @override
  Stream<Duration> get positionStream => _player.positionStream;

  @override
  Stream<Duration?> get durationStream => _player.durationStream;

  @override
  Stream<bool> get playingStream => _player.playingStream;

  @override
  Future<Duration?> setFilePath(String filePath) =>
      _player.setFilePath(filePath);

  @override
  Future<void> play() async {
    if (_player.processingState == ProcessingState.completed) {
      await _player.seek(Duration.zero);
    }
    await _player.play();
  }

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> dispose() => _player.dispose();
}

typedef ClipPlayerFactory = ClipAudioPlayer Function();

@immutable
class PlayableClip {
  const PlayableClip({required this.clip, this.sessionName});

  final AudioClip clip;
  final String? sessionName;
}

class PlayerSheet extends StatefulWidget {
  const PlayerSheet({
    super.key,
    required this.clip,
    this.sessionName,
    this.playlist,
    this.initialIndex = 0,
    this.playerFactory,
  });

  final AudioClip clip;
  final String? sessionName;
  final List<PlayableClip>? playlist;
  final int initialIndex;
  final ClipPlayerFactory? playerFactory;

  static Future<void> show({
    required BuildContext context,
    required AudioClip clip,
    String? sessionName,
    List<PlayableClip>? playlist,
    int initialIndex = 0,
    ClipPlayerFactory? playerFactory,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (BuildContext _) => PlayerSheet(
        clip: clip,
        sessionName: sessionName,
        playlist: playlist,
        initialIndex: initialIndex,
        playerFactory: playerFactory,
      ),
    );
  }

  @override
  State<PlayerSheet> createState() => _PlayerSheetState();
}

class _PlayerSheetState extends State<PlayerSheet> {
  late final ClipAudioPlayer _player;
  late final List<PlayableClip> _playlist;
  late int _currentIndex;
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<Duration?>? _durationSub;
  StreamSubscription<bool>? _playingSub;

  Duration _position = Duration.zero;
  late Duration _duration;
  double? _dragMs;
  bool _isPlaying = false;
  bool _isLoading = true;
  String? _errorText;
  int _loadEpoch = 0;

  PlayableClip get _currentItem => _playlist[_currentIndex];
  bool get _hasPrevious => _currentIndex > 0;
  bool get _hasNext => _currentIndex < _playlist.length - 1;

  @override
  void initState() {
    super.initState();
    final provided = widget.playlist;
    if (provided != null && provided.isNotEmpty) {
      _playlist = List<PlayableClip>.unmodifiable(provided);
      _currentIndex = widget.initialIndex.clamp(0, _playlist.length - 1);
    } else {
      _playlist = <PlayableClip>[
        PlayableClip(clip: widget.clip, sessionName: widget.sessionName),
      ];
      _currentIndex = 0;
    }

    _duration = _currentItem.clip.duration;
    _player = (widget.playerFactory ?? JustAudioClipPlayer.new)();

    _positionSub = _player.positionStream.listen((Duration pos) {
      if (!mounted) return;
      setState(() => _position = pos);
    });
    _durationSub = _player.durationStream.listen((Duration? dur) {
      if (!mounted || dur == null) return;
      setState(() => _duration = dur);
    });
    _playingSub = _player.playingStream.listen((bool playing) {
      if (!mounted) return;
      setState(() => _isPlaying = playing);
    });

    _loadCurrentClip();
  }

  Future<void> _loadCurrentClip({bool autoPlay = false}) async {
    final epoch = ++_loadEpoch;
    final item = _currentItem;

    try {
      if (_isPlaying) {
        await _player.pause();
      }
      final loadedDuration = await _player.setFilePath(item.clip.filePath);
      if (!mounted || epoch != _loadEpoch) return;
      setState(() {
        _position = Duration.zero;
        _dragMs = null;
        _errorText = null;
        _duration = loadedDuration ?? item.clip.duration;
        _isLoading = false;
      });
      if (autoPlay) {
        await _player.play();
      }
    } catch (_) {
      if (!mounted || epoch != _loadEpoch) return;
      setState(() {
        _isLoading = false;
        _errorText = 'Could not load audio file. It may have been removed.';
      });
    }
  }

  Future<void> _selectIndex(int index) async {
    if (index < 0 || index >= _playlist.length || index == _currentIndex) {
      return;
    }
    setState(() {
      _currentIndex = index;
      _position = Duration.zero;
      _dragMs = null;
      _duration = _playlist[index].clip.duration;
      _errorText = null;
      _isLoading = true;
    });
    await _loadCurrentClip(autoPlay: true);
  }

  Future<void> _togglePlayPause() async {
    if (_errorText != null || _isLoading) return;
    if (_isPlaying) {
      await _player.pause();
    } else {
      if (_duration > Duration.zero && _position >= _duration) {
        await _player.seek(Duration.zero);
      }
      await _player.play();
    }
  }

  Future<void> _skipBy(Duration delta) async {
    if (_errorText != null || _isLoading) return;
    final maxMs = _duration.inMilliseconds;
    final targetMs = (_position.inMilliseconds + delta.inMilliseconds).clamp(
      0,
      maxMs > 0 ? maxMs : 0,
    );
    await _player.seek(Duration(milliseconds: targetMs));
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _durationSub?.cancel();
    _playingSub?.cancel();
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final item = _currentItem;
    final totalMs = _duration.inMilliseconds.toDouble();
    final maxMs = totalMs > 0 ? totalMs : 1.0;
    final currentMs = (_dragMs ?? _position.inMilliseconds.toDouble()).clamp(
      0.0,
      maxMs,
    );

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              item.clip.name,
              style: theme.textTheme.titleLarge,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              <String>[
                if (item.sessionName != null) item.sessionName!,
                ClipTile.formatSize(item.clip.sizeBytes),
                if (_playlist.length > 1)
                  '${_currentIndex + 1} / ${_playlist.length} in folder',
              ].join(' • '),
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            if (_errorText != null) ...<Widget>[
              Card(
                color: colors.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    _errorText!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.onErrorContainer,
                    ),
                  ),
                ),
              ),
              if (_playlist.length > 1) ...<Widget>[
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    IconButton(
                      tooltip: 'Previous clip',
                      onPressed: _hasPrevious
                          ? () => _selectIndex(_currentIndex - 1)
                          : null,
                      icon: const Icon(Icons.skip_previous_rounded),
                      iconSize: 30,
                    ),
                    const SizedBox(width: 24),
                    IconButton(
                      tooltip: 'Next clip',
                      onPressed: _hasNext
                          ? () => _selectIndex(_currentIndex + 1)
                          : null,
                      icon: const Icon(Icons.skip_next_rounded),
                      iconSize: 30,
                    ),
                  ],
                ),
              ],
            ] else ...<Widget>[
              Slider(
                value: currentMs,
                max: maxMs,
                onChanged: _isLoading
                    ? null
                    : (double value) => setState(() => _dragMs = value),
                onChangeEnd: _isLoading
                    ? null
                    : (double value) async {
                        setState(() => _dragMs = null);
                        await _player.seek(
                          Duration(milliseconds: value.round()),
                        );
                      },
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    Text(
                      ClipTile.formatDuration(currentMs.round()),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      ClipTile.formatDuration(_duration.inMilliseconds),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  if (_playlist.length > 1) ...<Widget>[
                    IconButton(
                      tooltip: 'Previous clip',
                      onPressed: _hasPrevious
                          ? () => _selectIndex(_currentIndex - 1)
                          : null,
                      icon: const Icon(Icons.skip_previous_rounded),
                      iconSize: 30,
                    ),
                    const SizedBox(width: 4),
                  ],
                  IconButton(
                    tooltip: 'Back 5 seconds',
                    onPressed: _isLoading
                        ? null
                        : () => _skipBy(const Duration(seconds: -5)),
                    icon: const Icon(Icons.replay_5_rounded),
                    iconSize: 28,
                  ),
                  const SizedBox(width: 12),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      shape: const CircleBorder(),
                      padding: const EdgeInsets.all(16),
                    ),
                    onPressed: _isLoading ? null : _togglePlayPause,
                    child: _isLoading
                        ? SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: colors.onPrimary,
                            ),
                          )
                        : Icon(
                            _isPlaying
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                            size: 32,
                          ),
                  ),
                  const SizedBox(width: 12),
                  IconButton(
                    tooltip: 'Forward 5 seconds',
                    onPressed: _isLoading
                        ? null
                        : () => _skipBy(const Duration(seconds: 5)),
                    icon: const Icon(Icons.forward_5_rounded),
                    iconSize: 28,
                  ),
                  if (_playlist.length > 1) ...<Widget>[
                    const SizedBox(width: 4),
                    IconButton(
                      tooltip: 'Next clip',
                      onPressed: _hasNext
                          ? () => _selectIndex(_currentIndex + 1)
                          : null,
                      icon: const Icon(Icons.skip_next_rounded),
                      iconSize: 30,
                    ),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
