import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';

class RecordButton extends StatelessWidget {
  const RecordButton.start({
    super.key,
    required this.onPressed,
    this.isLoading = false,
  }) : _isStop = false;

  const RecordButton.stop({
    super.key,
    required this.onPressed,
    this.isLoading = false,
  }) : _isStop = true;

  final VoidCallback? onPressed;
  final bool isLoading;
  final bool _isStop;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final recordingColors = theme.extension<AppRecordingColors>()!;

    final backgroundColor = _isStop
        ? recordingColors.recording
        : theme.colorScheme.primary;
    final foregroundColor = _isStop
        ? recordingColors.onRecording
        : theme.colorScheme.onPrimary;

    return SizedBox(
      width: double.infinity,
      height: 58,
      child: FilledButton.icon(
        onPressed: isLoading ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: foregroundColor,
          shape: const StadiumBorder(),
        ),
        icon: isLoading
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: foregroundColor,
                ),
              )
            : Icon(_isStop ? Icons.stop_rounded : Icons.fiber_manual_record),
        label: Text(
          _isStop ? 'Stop Session' : 'Record Now',
          style: theme.textTheme.titleMedium?.copyWith(
            color: foregroundColor,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
