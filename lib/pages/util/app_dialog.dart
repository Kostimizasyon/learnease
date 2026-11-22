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

/// Reusable modal dialogs with modern icon-badged headers and semantic named constructors.
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
          icon: _DialogIconBadge(
            icon: Icons.delete_outline_rounded,
            backgroundColor: recordingColors.recordingContainer,
            iconColor: recordingColors.onRecordingContainer,
          ),
          title: Text(title, textAlign: TextAlign.center),
          content: Text(message, textAlign: TextAlign.center),
          actionsPadding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          actions: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(dialogContext).pop(false),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: recordingColors.recording,
                      foregroundColor: recordingColors.onRecording,
                    ),
                    onPressed: () => Navigator.of(dialogContext).pop(true),
                    child: Text(confirmLabel),
                  ),
                ),
              ],
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
          icon: _DialogIconBadge(
            icon: Icons.drive_file_move_outlined,
            backgroundColor: colors.primaryContainer,
            iconColor: colors.onPrimaryContainer,
          ),
          title: Text(title, textAlign: TextAlign.center),
          contentPadding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          content: SizedBox(
            width: double.maxFinite,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 300),
              child: ListView(
                shrinkWrap: true,
                children: <Widget>[
                  _FolderPickOption(
                    icon: Icons.home_outlined,
                    label: 'Library (Root)',
                    selected: currentFolderId == null,
                    onTap: () =>
                        Navigator.of(dialogContext)
                            .pop(const FolderMoveSelection.root()),
                  ),
                  if (eligible.isNotEmpty) const SizedBox(height: 6),
                  for (final folder in eligible) ...<Widget>[
                    _FolderPickOption(
                      icon: folder.isRoot
                          ? Icons.folder_outlined
                          : Icons.subdirectory_arrow_right_rounded,
                      label: folder.name,
                      selected: currentFolderId == folder.id,
                      onTap: () =>
                          Navigator.of(dialogContext)
                              .pop(FolderMoveSelection.folder(folder.id!)),
                    ),
                    const SizedBox(height: 4),
                  ],
                ],
              ),
            ),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          actions: <Widget>[
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Cancel'),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _DialogIconBadge extends StatelessWidget {
  const _DialogIconBadge({
    required this.icon,
    required this.backgroundColor,
    required this.iconColor,
  });

  final IconData icon;
  final Color backgroundColor;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(color: backgroundColor, shape: BoxShape.circle),
      child: Icon(icon, color: iconColor, size: 26),
    );
  }
}

class _FolderPickOption extends StatelessWidget {
  const _FolderPickOption({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: selected ? colors.primaryContainer : colors.surfaceContainer,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        dense: true,
        leading: Icon(
          icon,
          color: selected ? colors.onPrimaryContainer : colors.onSurfaceVariant,
        ),
        title: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            color: selected ? colors.onPrimaryContainer : colors.onSurface,
          ),
        ),
        trailing: selected
            ? Icon(
                Icons.check_circle_rounded,
                color: colors.onPrimaryContainer,
                size: 20,
              )
            : null,
        onTap: onTap,
      ),
    );
  }
}

class _TextInputDialog extends StatefulWidget {
  const _TextInputDialog.rename({
    required this.title,
    required this.initialValue,
    required this.labelText,
  }) : confirmLabel = 'Save',
       subtitle = 'Choose a clear name to find this item quickly.',
       hintText = 'Enter name',
       icon = Icons.edit_outlined;

  const _TextInputDialog.createFolder({required this.title})
    : initialValue = '',
      labelText = 'Folder name',
      hintText = 'e.g. Japanese, Podcasts, Lectures',
      subtitle = 'Group related recording sessions cleanly.',
      confirmLabel = 'Create',
      icon = Icons.create_new_folder_outlined;

  final String title;
  final String subtitle;
  final String initialValue;
  final String labelText;
  final String hintText;
  final String confirmLabel;
  final IconData icon;

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
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return AlertDialog(
      icon: _DialogIconBadge(
        icon: widget.icon,
        backgroundColor: colors.primaryContainer,
        iconColor: colors.onPrimaryContainer,
      ),
      title: Text(widget.title, textAlign: TextAlign.center),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            widget.subtitle,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            autofocus: true,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              labelText: widget.labelText,
              hintText: widget.hintText,
              errorText: _errorText,
            ),
            onChanged: (_) {
              if (_errorText != null) {
                setState(() => _errorText = null);
              }
            },
            onSubmitted: (_) => _submit(),
          ),
        ],
      ),
      actionsPadding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
      actions: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                onPressed: _submit,
                child: Text(widget.confirmLabel),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
