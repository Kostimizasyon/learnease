import 'package:flutter/material.dart';

import '../../../data_models/audio_clip.dart';
import '../../../data_models/recording_session.dart';
import '../../../theme/app_theme.dart';
import 'clip_tile.dart';

enum _SessionAction { rename, move, delete }

class SessionTile extends StatefulWidget {
  const SessionTile.completed({
    super.key,
    required this.session,
    required this.clips,
    required this.onPlayClip,
    required this.onRenameSession,
    required this.onMoveSession,
    required this.onDeleteSession,
    required this.onRenameClip,
    required this.onDeleteClip,
    this.initiallyExpanded = false,
  }) : _isActive = false;

  const SessionTile.active({
    super.key,
    required this.session,
    required this.clips,
    required this.onPlayClip,
    required this.onRenameSession,
    required this.onMoveSession,
    required this.onDeleteSession,
    required this.onRenameClip,
    required this.onDeleteClip,
    this.initiallyExpanded = true,
  }) : _isActive = true;

  final RecordingSession session;
  final List<AudioClip> clips;
  final ValueChanged<AudioClip> onPlayClip;
  final VoidCallback onRenameSession;
  final VoidCallback onMoveSession;
  final VoidCallback onDeleteSession;
  final ValueChanged<AudioClip> onRenameClip;
  final ValueChanged<AudioClip> onDeleteClip;
  final bool initiallyExpanded;
  final bool _isActive;

  @override
  State<SessionTile> createState() => _SessionTileState();
}

class _SessionTileState extends State<SessionTile> {
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = widget.initiallyExpanded;
  }

  String _subtitle() {
    final started = widget.session.startedAt;
    final h = started.hour.toString().padLeft(2, '0');
    final min = started.minute.toString().padLeft(2, '0');
    final count = widget.clips.length;
    final clipLabel = count == 1 ? '1 clip' : '$count clips';
    final statusSuffix = widget._isActive ? ' • Live' : '';
    return '$h:$min • ${widget.session.bufferSeconds}s • $clipLabel$statusSuffix';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final recordingColors = theme.extension<AppRecordingColors>()!;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: <Widget>[
          ListTile(
            leading: widget._isActive
                ? CircleAvatar(
                    radius: 18,
                    backgroundColor: recordingColors.recordingContainer,
                    child: Icon(
                      Icons.graphic_eq_rounded,
                      size: 18,
                      color: recordingColors.onRecordingContainer,
                    ),
                  )
                : CircleAvatar(
                    radius: 18,
                    backgroundColor: colors.primaryContainer,
                    child: Icon(
                      Icons.audiotrack_rounded,
                      size: 18,
                      color: colors.onPrimaryContainer,
                    ),
                  ),
            title: Text(
              widget.session.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              _subtitle(),
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
            onTap: () => setState(() => _expanded = !_expanded),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(
                  _expanded
                      ? Icons.expand_less_rounded
                      : Icons.expand_more_rounded,
                  color: colors.onSurfaceVariant,
                ),
                PopupMenuButton<_SessionAction>(
                  tooltip: 'Session options',
                  onSelected: (_SessionAction action) {
                    switch (action) {
                      case _SessionAction.rename:
                        widget.onRenameSession();
                      case _SessionAction.move:
                        widget.onMoveSession();
                      case _SessionAction.delete:
                        widget.onDeleteSession();
                    }
                  },
                  itemBuilder: (BuildContext _) =>
                      const <PopupMenuEntry<_SessionAction>>[
                        PopupMenuItem<_SessionAction>(
                          value: _SessionAction.rename,
                          child: Text('Rename'),
                        ),
                        PopupMenuItem<_SessionAction>(
                          value: _SessionAction.move,
                          child: Text('Move to folder'),
                        ),
                        PopupMenuItem<_SessionAction>(
                          value: _SessionAction.delete,
                          child: Text('Delete'),
                        ),
                      ],
                ),
              ],
            ),
          ),
          if (_expanded) ...<Widget>[
            const Divider(),
            if (widget.clips.isEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'No clips saved in this session.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              )
            else
              for (var i = 0; i < widget.clips.length; i++) ...<Widget>[
                if (i > 0) const Divider(indent: 16, endIndent: 16),
                ClipTile.standard(
                  clip: widget.clips[i],
                  onPlay: () => widget.onPlayClip(widget.clips[i]),
                  onRename: () => widget.onRenameClip(widget.clips[i]),
                  onDelete: () => widget.onDeleteClip(widget.clips[i]),
                ),
              ],
          ],
        ],
      ),
    );
  }
}
