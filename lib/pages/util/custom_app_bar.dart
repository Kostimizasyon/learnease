import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  const CustomAppBar.standard({super.key, required this.title, this.actions})
    : _isRecording = false;

  const CustomAppBar.recording({super.key, required this.title, this.actions})
    : _isRecording = true;

  final String title;
  final List<Widget>? actions;
  final bool _isRecording;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final recordingColors = theme.extension<AppRecordingColors>()!;

    return AppBar(
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (_isRecording) ...<Widget>[
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: recordingColors.recording,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 10),
          ],
          Text(title),
        ],
      ),
      actions: actions,
    );
  }
}
