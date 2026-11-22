import 'package:flutter/material.dart';

import '../../../data_models/audio_clip.dart';

enum _ClipAction { rename, delete }

class ClipTile extends StatelessWidget {
  const ClipTile.standard({
    super.key,
    required this.clip,
    required this.onPlay,
    required this.onRename,
    required this.onDelete,
  }) : _compact = false;

  const ClipTile.compact({
    super.key,
    required this.clip,
    required this.onPlay,
    required this.onRename,
    required this.onDelete,
  }) : _compact = true;

  final AudioClip clip;
  final VoidCallback onPlay;
  final VoidCallback onRename;
  final VoidCallback onDelete;
  final bool _compact;

  static String formatDuration(int durationMs) {
    final totalSeconds = (durationMs / 1000).round();
    final minutes = totalSeconds ~/ 60;
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  static String formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return ListTile(
      dense: _compact,
      contentPadding: EdgeInsets.symmetric(
        horizontal: _compact ? 12 : 16,
        vertical: _compact ? 0 : 2,
      ),
      leading: IconButton.filledTonal(
        onPressed: onPlay,
        tooltip: 'Play ${clip.name}',
        icon: const Icon(Icons.play_arrow_rounded),
      ),
      title: Text(clip.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        '${formatDuration(clip.durationMs)} • ${formatSize(clip.sizeBytes)}',
        style: theme.textTheme.bodySmall?.copyWith(
          color: colors.onSurfaceVariant,
        ),
      ),
      onTap: onPlay,
      trailing: PopupMenuButton<_ClipAction>(
        tooltip: 'Clip options',
        onSelected: (_ClipAction action) {
          switch (action) {
            case _ClipAction.rename:
              onRename();
            case _ClipAction.delete:
              onDelete();
          }
        },
        itemBuilder: (BuildContext _) => const <PopupMenuEntry<_ClipAction>>[
          PopupMenuItem<_ClipAction>(
            value: _ClipAction.rename,
            child: Text('Rename'),
          ),
          PopupMenuItem<_ClipAction>(
            value: _ClipAction.delete,
            child: Text('Delete'),
          ),
        ],
      ),
    );
  }
}
