import 'package:flutter/material.dart';

import '../../services/permission_service.dart';
import '../../services/recorder_channel.dart';

/// Guides the user through granting required Android permissions before starting a session,
/// automatically refreshing when returning from Android system Settings (e.g. overlay toggle).
class PermissionGate extends StatefulWidget {
  const PermissionGate.sessionSetup({
    super.key,
    required this.permissionService,
    required this.onReady,
    this.recorderChannel,
    this.onCancel,
  }) : _overlayOnly = false;

  const PermissionGate.overlayOnly({
    super.key,
    required this.permissionService,
    required this.onReady,
    this.recorderChannel,
    this.onCancel,
  }) : _overlayOnly = true;

  final PermissionService permissionService;
  final RecorderChannel? recorderChannel;
  final VoidCallback onReady;
  final VoidCallback? onCancel;
  final bool _overlayOnly;

  @override
  State<PermissionGate> createState() => _PermissionGateState();
}

class _PermissionGateState extends State<PermissionGate>
    with WidgetsBindingObserver {
  PermissionCheckResult? _status;
  bool _checking = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshStatus();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshStatus();
    }
  }

  Future<void> _refreshStatus() async {
    setState(() => _checking = true);
    var result = await widget.permissionService.checkAll();
    if (!result.overlayGranted && widget.recorderChannel != null) {
      final nativeOverlay = await widget.recorderChannel!
          .hasOverlayPermission();
      if (nativeOverlay) {
        result = PermissionCheckResult(
          audioGranted: result.audioGranted,
          notificationGranted: result.notificationGranted,
          overlayGranted: true,
          permanentlyDenied: result.permanentlyDenied,
        );
      }
    }
    if (!mounted) return;
    setState(() {
      _status = result;
      _checking = false;
    });
  }

  bool _isSatisfied(PermissionCheckResult result) {
    if (widget._overlayOnly) {
      return result.overlayGranted;
    }
    return result.audioGranted && result.overlayGranted;
  }

  Future<void> _requestStandardPermissions() async {
    setState(() => _busy = true);
    try {
      await widget.permissionService.requestRecordingPermissions(
        includeOverlay: false,
      );
      await _refreshStatus();
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _requestOverlayPermission() async {
    setState(() => _busy = true);
    try {
      final channel = widget.recorderChannel;
      if (channel != null) {
        await channel.openOverlayPermissionSettings();
      } else {
        await widget.permissionService.requestOverlayPermission();
      }
      await _refreshStatus();
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _openAppSettings() async {
    await widget.permissionService.openSettings();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final status = _status;

    if (_checking || status == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: CircularProgressIndicator(),
        ),
      );
    }

    final satisfied = _isSatisfied(status);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              widget._overlayOnly
                  ? 'Floating Button Permission'
                  : 'Permissions Required',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              widget._overlayOnly
                  ? 'Learnese needs permission to show the floating save button over other apps.'
                  : 'Grant these Android permissions so Learnese can buffer audio output and show the floating save button.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            if (!widget._overlayOnly) ...<Widget>[
              _PermissionRow(
                icon: Icons.hearing_rounded,
                title: 'Audio Output Capture',
                subtitle: 'Required by Android for playback capture. Learnese never records the microphone.',
                granted: status.audioGranted,
                actionLabel: status.permanentlyDenied ? 'Settings' : 'Allow',
                onAction: _busy
                    ? null
                    : (status.permanentlyDenied
                          ? _openAppSettings
                          : _requestStandardPermissions),
              ),
              const Divider(height: 20),
              _PermissionRow(
                icon: Icons.notifications_active_outlined,
                title: 'Session Notification',
                subtitle: 'Shows that buffering is active and lets you stop the session anytime.',
                granted: status.notificationGranted,
                actionLabel: 'Allow',
                onAction: _busy ? null : _requestStandardPermissions,
              ),
              const Divider(height: 20),
            ],
            _PermissionRow(
              icon: Icons.picture_in_picture_alt_rounded,
              title: 'Display Over Other Apps',
              subtitle: 'Shows the draggable save button over other apps. Dragging it to X ends the session.',
              granted: status.overlayGranted,
              actionLabel: 'Enable',
              onAction: _busy ? null : _requestOverlayPermission,
            ),
            const SizedBox(height: 20),
            Row(
              children: <Widget>[
                if (widget.onCancel != null) ...<Widget>[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: widget.onCancel,
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: FilledButton(
                    onPressed: satisfied ? widget.onReady : null,
                    child: const Text('Continue'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PermissionRow extends StatelessWidget {
  const _PermissionRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.granted,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool granted;
  final String actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Icon(
          icon,
          color: granted ? colors.primary : colors.onSurfaceVariant,
          size: 22,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(title, style: theme.textTheme.titleSmall),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        if (granted)
          Icon(Icons.check_circle_rounded, color: colors.primary, size: 22)
        else
          TextButton(onPressed: onAction, child: Text(actionLabel)),
      ],
    );
  }
}
