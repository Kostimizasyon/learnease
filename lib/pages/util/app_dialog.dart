import 'package:flutter/material.dart';

import '../../data_models/folder.dart';
import '../../theme/app_theme.dart';

/// Distinguishes a deliberate move to Root (`folderId == null`) from dialog cancellation.
@immutable
class FolderMoveSelection {
  const FolderMoveSelection.root() : folderId = null;

  const FolderMoveSelection.folder(int id) : folderId = id;

  final int? folderId;
}

/// Reusable modal dialogs with semantic named constructors.
abstract final class AppDialog {
  static Future<String?> rename({
    required BuildContext context,
    required String title,
    required String initialValue,
    String labelText = 'Name',
  }) {
    return showDialog<String>(
      context: context,
      builder: (BuildContext _) => _TextInputDialog.rename(
        title: title,
        initialValue: initialValue,
        labelText: labelText,
      ),
    );
  }

  static Future<String?> createFolder({
    required BuildContext context,
    String title = 'New Folder',
  }) {
    return showDialog<String>(
      context: context,
      builder: (BuildContext _) => _TextInputDialog.createFolder(title: title),
    );
  }

  static Future<bool> confirmDelete({
    required BuildContext context,
    required String title,
    required String message,
    String confirmLabel = 'Delete',
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        final recordingColors = Theme.of(dialogContext)
            .extension<AppRecordingColors>()!;
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: recordingColors.recording,
                foregroundColor: recordingColors.onRecording,
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(confirmLabel),
            ),
          ],
        );
      },
    );
    return result ?? false;
  }

  static Future<FolderMoveSelection?> pickFolder({
    required BuildContext context,
    required String title,
    required List<Folder> allFolders,
    int? currentFolderId,
    Set<int> excludedFolderIds = const <int>{},
  }) {
    final eligible = allFolders
        .where((Folder f) => f.id != null && !excludedFolderIds.contains(f.id))
        .toList(growable: false);

    return showDialog<FolderMoveSelection>(
      context: context,
      builder: (BuildContext dialogContext) {
        final colors = Theme.of(dialogContext).colorScheme;
        return AlertDialog(
          title: Text(title),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView(
              shrinkWrap: true,
              children: <Widget>[
                ListTile(
                  leading: Icon(
                    Icons.home_outlined,
                    color: currentFolderId == null
                        ? colors.primary
                        : colors.onSurfaceVariant,
                  ),
                  title: const Text('Library (Root)'),
                  trailing: currentFolderId == null
                      ? Icon(Icons.check_rounded, color: colors.primary)
                      : null,
                  onTap: () =>
                      Navigator.of(dialogContext)
                          .pop(const FolderMoveSelection.root()),
                ),
                if (eligible.isNotEmpty) const Divider(),
                for (final folder in eligible)
                  ListTile(
                    leading: Icon(
                      folder.isRoot
                          ? Icons.folder_outlined
                          : Icons.subdirectory_arrow_right_rounded,
                      color: currentFolderId == folder.id
                          ? colors.primary
                          : colors.onSurfaceVariant,
                    ),
                    title: Text(folder.name),
                    trailing: currentFolderId == folder.id
                        ? Icon(Icons.check_rounded, color: colors.primary)
                        : null,
                    onTap: () =>
                        Navigator.of(dialogContext)
                            .pop(FolderMoveSelection.folder(folder.id!)),
                  ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }
}

class _TextInputDialog extends StatefulWidget {
  const _TextInputDialog.rename({
    required this.title,
    required this.initialValue,
    required this.labelText,
  }) : confirmLabel = 'Save';

  const _TextInputDialog.createFolder({required this.title})
    : initialValue = '',
      labelText = 'Folder name',
      confirmLabel = 'Create';

  final String title;
  final String initialValue;
  final String labelText;
  final String confirmLabel;

  @override
  State<_TextInputDialog> createState() => _TextInputDialogState();
}

class _TextInputDialogState extends State<_TextInputDialog> {
  late final TextEditingController _controller;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final trimmed = _controller.text.trim();
    if (trimmed.isEmpty) {
      setState(() => _errorText = 'Name cannot be empty.');
      return;
    }
    Navigator.of(context).pop(trimmed);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textInputAction: TextInputAction.done,
        decoration: InputDecoration(
          labelText: widget.labelText,
          errorText: _errorText,
        ),
        onSubmitted: (_) => _submit(),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: Text(widget.confirmLabel)),
      ],
    );
  }
}
