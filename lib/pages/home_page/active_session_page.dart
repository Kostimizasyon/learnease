import 'package:flutter/material.dart';

import '../../services/session_controller.dart';
import '../../theme/app_theme.dart';
import 'util/record_button.dart';

class ActiveSessionPage extends StatelessWidget {
  const ActiveSessionPage({
    super.key,
    required this.controller,
    required this.onOpenLibrary,
  });

  final SessionController controller;
  final VoidCallback onOpenLibrary;

  String _formatBufferedSeconds(int bufferedMs) {
    final seconds = bufferedMs / 1000.0;
    return seconds >= 10
        ? '${seconds.toStringAsFixed(0)}s'
        : '${seconds.toStringAsFixed(1)}s';
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (BuildContext context, Widget? _) {
        final theme = Theme.of(context);
        final colors = theme.colorScheme;
        final recordingColors = theme.extension<AppRecordingColors>()!;
        final state = controller.recordingState;
        final session = controller.activeSession;
        final bufferSeconds =
            session?.bufferSeconds ??
            (state.bufferSeconds > 0
                ? state.bufferSeconds
                : controller.selectedBufferSeconds);
        final fillFraction = bufferSeconds > 0
            ? (state.bufferedMs / (bufferSeconds * 1000)).clamp(0.0, 1.0)
            : 0.0;
        final clipCount = controller.activeClipCount;
        final statusMessage = controller.statusMessage;

        return Scaffold(
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 96),
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: recordingColors.recording,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Active Session',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Card(
                  color: recordingColors.recordingContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: <Widget>[
                        Icon(
                          Icons.graphic_eq_rounded,
                          color: recordingColors.onRecordingContainer,
                          size: 28,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                'Buffering last ${bufferSeconds}s',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  color: recordingColors.onRecordingContainer,
                                ),
                              ),
                              if (session != null) ...<Widget>[
                                const SizedBox(height: 2),
                                Text(
                                  session.name,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: recordingColors.onRecordingContainer,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                if (statusMessage != null) ...<Widget>[
                  Card(
                    color: colors.errorContainer,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      child: Row(
                        children: <Widget>[
                          Expanded(
                            child: Text(
                              statusMessage,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colors.onErrorContainer,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: controller.clearStatusMessage,
                            icon: Icon(
                              Icons.close_rounded,
                              size: 18,
                              color: colors.onErrorContainer,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: <Widget>[
                            Text(
                              'Rolling Memory Buffer',
                              style: theme.textTheme.titleSmall,
                            ),
                            Text(
                              '${_formatBufferedSeconds(state.bufferedMs)} / ${bufferSeconds}s',
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: colors.primary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: fillFraction,
                            minHeight: 8,
                          ),
                        ),
                        if (state.bufferedMs == 0) ...<Widget>[
                          const SizedBox(height: 6),
                          Text(
                            'Waiting for device audio output…',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),
                        const Divider(),
                        const SizedBox(height: 14),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: <Widget>[
                            Text(
                              'Clips Saved This Session',
                              style: theme.textTheme.titleSmall,
                            ),
                            Text(
                              '$clipCount',
                              key: const Key('active_session_clip_count'),
                              style: theme.textTheme.headlineSmall?.copyWith(
                                color: colors.primary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: controller.isBusy ? null : controller.saveClipNow,
                  icon: const Icon(Icons.replay_rounded),
                  label: Text('Save Last ${bufferSeconds}s Now'),
                ),
                const SizedBox(height: 12),
                RecordButton.stop(
                  isLoading: controller.isBusy,
                  onPressed: controller.stopSession,
                ),
                const SizedBox(height: 12),
                TextButton.icon(
                  onPressed: onOpenLibrary,
                  icon: const Icon(Icons.library_music_outlined),
                  label: const Text('Open Library'),
                ),
                const SizedBox(height: 12),
                Card(
                  color: colors.surfaceContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Text(
                      'Switch to any app and tap the floating button to save a clip. '
                      'Dragging the floating button onto X ends this session and discards unsaved buffer audio.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
