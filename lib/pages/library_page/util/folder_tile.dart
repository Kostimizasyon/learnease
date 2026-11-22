import 'package:flutter/material.dart';

import '../../../data_models/folder.dart';

enum _FolderAction { rename, move, delete }

class FolderTile extends StatelessWidget {
  const FolderTile.root({
    super.key,
    required this.folder,
    required this.onOpen,
    required this.onRename,
    required this.onMove,
    required this.onDelete,
  }) : _isNested = false;

  const FolderTile.nested({
    super.key,
    required this.folder,
    required this.onOpen,
    required this.onRename,
    required this.onMove,
    required this.onDelete,
  }) : _isNested = true;

  final Folder folder;
  final VoidCallback onOpen;
  final VoidCallback onRename;
  final VoidCallback onMove;
  final VoidCallback onDelete;
  final bool _isNested;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Card(
      child: ListTile(
        leading: Icon(
          _isNested ? Icons.folder_copy_outlined : Icons.folder_outlined,
          color: colors.primary,
        ),
        title: Text(folder.name, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: _isNested
            ? Text(
                'Sub-folder',
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: colors.onSurfaceVariant),
              )
            : null,
        onTap: onOpen,
        trailing: PopupMenuButton<_FolderAction>(
          tooltip: 'Folder options',
          onSelected: (_FolderAction action) {
            switch (action) {
              case _FolderAction.rename:
                onRename();
              case _FolderAction.move:
                onMove();
              case _FolderAction.delete:
                onDelete();
            }
          },
          itemBuilder: (BuildContext _) =>
              const <PopupMenuEntry<_FolderAction>>[
                PopupMenuItem<_FolderAction>(
                  value: _FolderAction.rename,
                  child: Text('Rename'),
                ),
                PopupMenuItem<_FolderAction>(
                  value: _FolderAction.move,
                  child: Text('Move'),
                ),
                PopupMenuItem<_FolderAction>(
                  value: _FolderAction.delete,
                  child: Text('Delete'),
                ),
              ],
        ),
      ),
    );
  }
}
