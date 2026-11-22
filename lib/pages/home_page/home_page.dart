import 'package:flutter/material.dart';

import '../../services/session_controller.dart';
import '../../theme/app_colors.dart';
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

  void _showCaptureInfoSheet(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext _) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 4, 24, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: colors.primaryContainer,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.shield_outlined,
                        color: colors.onPrimaryContainer,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'How Playback Capture Works',
                      style: theme.textTheme.titleMedium,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  '• Captures device audio output only — never the microphone.\n'
                  '• Unsaved buffer audio stays strictly in RAM and is cleared on save or stop.\n'
                  '• Continuous buffering uses battery/RAM and shows Android’s recording indicator.\n'
                  '• Apps can opt out of capture and DRM/protected media records as silence.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                    height: 1.55,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
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
          body: SafeArea(
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 96),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: (constraints.maxHeight - 108).clamp(
                        0.0,
                        double.infinity,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            Align(
                              alignment: Alignment.centerRight,
                              child: IconButton(
                                tooltip: 'How capture works',
                                onPressed: () => _showCaptureInfoSheet(context),
                                icon: Icon(
                                  Icons.info_outline_rounded,
                                  color: colors.onSurfaceVariant,
                                ),
                              ),
                            ),
                            if (statusMessage != null) ...<Widget>[
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: colors.errorContainer,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Row(
                                  children: <Widget>[
                                    Icon(
                                      Icons.info_outline_rounded,
                                      size: 18,
                                      color: colors.onErrorContainer,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        statusMessage,
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
                                              color: colors.onErrorContainer,
                                            ),
                                      ),
                                    ),
                                    IconButton(
                                      onPressed: controller.clearStatusMessage,
                                      visualDensity: VisualDensity.compact,
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
                            ],
                          ],
                        ),
                        Column(
                          children: <Widget>[
                            Container(
                              width: 84,
                              height: 84,
                              decoration: BoxDecoration(
                                color: colors.primaryContainer,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.graphic_eq_rounded,
                                size: 40,
                                color: colors.onPrimaryContainer,
                              ),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              '${controller.selectedBufferSeconds}s',
                              style: theme.textTheme.displayMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: colors.onSurface,
                                letterSpacing: -1,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Audio instant replay • output only',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 32),
                            BufferLengthPicker(
                              selectedSeconds: controller.selectedBufferSeconds,
                              enabled: !controller.isBusy,
                              onChanged: controller.setBufferSeconds,
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            const SizedBox(height: 28),
                            RecordButton.start(
                              isLoading: controller.isBusy,
                              onPressed: () => _handleRecordNow(context),
                            ),
                            const SizedBox(height: 8),
                            Center(
                              child: TextButton(
                                onPressed: () => _showCaptureInfoSheet(context),
                                child: Text(
                                  'RAM-only buffer • Never uses mic • DRM apps silent',
                                  textAlign: TextAlign.center,
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: colors.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}
