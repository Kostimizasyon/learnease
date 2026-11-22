import 'package:flutter/material.dart';

import '../../services/session_controller.dart';
import '../../theme/app_colors.dart';
import '../util/custom_app_bar.dart';
import '../util/permission_gate.dart';
import 'active_session_page.dart';
import 'util/buffer_length_picker.dart';
import 'util/record_button.dart';

class HomePage extends StatelessWidget {
  const HomePage({
    super.key,
    required this.controller,
    required this.onOpenLibrary,
  });

  final SessionController controller;
  final VoidCallback onOpenLibrary;

  Future<void> _handleRecordNow(BuildContext context) async {
    final ready = await controller.hasRequiredPermissions();
    if (!context.mounted) return;

    if (!ready) {
      final granted = await showDialog<bool>(
        context: context,
        builder: (BuildContext dialogContext) {
          return Dialog(
            backgroundColor: AppColors.transparent,
            elevation: 0,
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 24,
            ),
            child: PermissionGate.sessionSetup(
              permissionService: controller.permissionService,
              recorderChannel: controller.recorderChannel,
              onReady: () => Navigator.of(dialogContext).pop(true),
              onCancel: () => Navigator.of(dialogContext).pop(false),
            ),
          );
        },
      );
      if (granted != true || !context.mounted) {
        return;
      }
    }

    await controller.startSession();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (BuildContext context, Widget? _) {
        if (controller.isSessionActive) {
          return ActiveSessionPage(
            controller: controller,
            onOpenLibrary: onOpenLibrary,
          );
        }

        final theme = Theme.of(context);
        final colors = theme.colorScheme;
        final statusMessage = controller.statusMessage;

        return Scaffold(
          appBar: const CustomAppBar.standard(title: 'Learnese'),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: <Widget>[
                Text(
                  'Audio Instant Replay',
                  style: theme.textTheme.headlineSmall,
                ),
                const SizedBox(height: 6),
                Text(
                  'Keep a rolling buffer of device audio output in memory and tap the floating button anytime to save the last ${controller.selectedBufferSeconds}s.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 20),
                if (statusMessage != null) ...<Widget>[
                  Card(
                    color: colors.errorContainer,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Row(
                        children: <Widget>[
                          Icon(
                            Icons.info_outline_rounded,
                            color: colors.onErrorContainer,
                          ),
                          const SizedBox(width: 12),
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
                            tooltip: 'Dismiss',
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
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        BufferLengthPicker(
                          selectedSeconds: controller.selectedBufferSeconds,
                          enabled: !controller.isBusy,
                          onChanged: controller.setBufferSeconds,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Buffer length stays fixed for the entire session. Capture runs until you stop it.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                RecordButton.start(
                  isLoading: controller.isBusy,
                  onPressed: () => _handleRecordNow(context),
                ),
                const SizedBox(height: 24),
                Card(
                  color: colors.surfaceContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Icon(
                              Icons.shield_outlined,
                              size: 18,
                              color: colors.primary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'How Playback Capture Works',
                              style: theme.textTheme.titleSmall,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '• Captures device audio output only — never the microphone.\n'
                          '• Unsaved buffer audio stays strictly in RAM and is discarded when you stop.\n'
                          '• Continuous buffering uses battery/RAM and shows Android’s recording indicator.\n'
                          '• Apps can opt out of capture and DRM/protected media records as silence.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colors.onSurfaceVariant,
                            height: 1.45,
                          ),
                        ),
                      ],
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
