import 'package:flutter/material.dart';

import '../../data_models/audio_clip.dart';
import '../../data_models/folder.dart';
import '../../data_models/recording_session.dart';
import '../../services/library_controller.dart';
import '../util/app_dialog.dart';
import '../util/custom_app_bar.dart';
import 'player_sheet.dart';
import 'util/folder_tile.dart';
import 'util/session_tile.dart';

class LibraryPage extends StatefulWidget {
  const LibraryPage({super.key, required this.controller, this.playerFactory});

  final LibraryController controller;
  final ClipPlayerFactory? playerFactory;

  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  @override
  void initState() {
    super.initState();
    widget.controller.load();
  }

  Future<void> _handleCreateFolder(BuildContext context) async {
    final name = await AppDialog.createFolder(context: context);
    if (name == null || !mounted) return;
    await widget.controller.createFolder(name);
  }

  Future<void> _handleRenameFolder(BuildContext context, Folder folder) async {
    final id = folder.id;
    if (id == null) return;
    final renamed = await AppDialog.rename(
      context: context,
      title: 'Rename Folder',
      initialValue: folder.name,
    );
    if (renamed == null || !mounted) return;
    await widget.controller.renameFolder(id, renamed);
  }

  Future<void> _handleMoveFolder(BuildContext context, Folder folder) async {
    final id = folder.id;
    if (id == null) return;
    final selection = await AppDialog.pickFolder(
      context: context,
      title: 'Move "${folder.name}"',
      allFolders: widget.controller.allFolders,
      currentFolderId: folder.parentId,
      excludedFolderIds: widget.controller.excludedMoveTargetsForFolder(id),
    );
    if (selection == null || !mounted) return;
    await widget.controller.moveFolder(id, newParentId: selection.folderId);
  }

  Future<void> _handleDeleteFolder(BuildContext context, Folder folder) async {
    final id = folder.id;
    if (id == null) return;
    final confirmed = await AppDialog.confirmDelete(
      context: context,
      title: 'Delete Folder?',
      message:
          'Delete "${folder.name}" and any sub-folders inside it? Recorded sessions will be moved back to Library root.',
    );
    if (!confirmed || !mounted) return;
    await widget.controller.deleteFolder(id);
  }

  Future<void> _handleRenameSession(
    BuildContext context,
    RecordingSession session,
  ) async {
    final id = session.id;
    if (id == null) return;
    final renamed = await AppDialog.rename(
      context: context,
      title: 'Rename Session',
      initialValue: session.name,
    );
    if (renamed == null || !mounted) return;
    await widget.controller.renameSession(id, renamed);
  }

  Future<void> _handleMoveSession(
    BuildContext context,
    RecordingSession session,
  ) async {
    final id = session.id;
    if (id == null) return;
    final selection = await AppDialog.pickFolder(
      context: context,
      title: 'Move "${session.name}"',
      allFolders: widget.controller.allFolders,
      currentFolderId: session.folderId,
    );
    if (selection == null || !mounted) return;
    await widget.controller.moveSession(id, folderId: selection.folderId);
  }

  Future<void> _handleDeleteSession(
    BuildContext context,
    RecordingSession session,
  ) async {
    final id = session.id;
    if (id == null) return;
    final confirmed = await AppDialog.confirmDelete(
      context: context,
      title: 'Delete Session?',
      message:
          'Delete "${session.name}" and permanently remove all audio clips saved in it?',
    );
    if (!confirmed || !mounted) return;
    await widget.controller.deleteSession(id);
  }

  Future<void> _handleRenameClip(BuildContext context, AudioClip clip) async {
    final id = clip.id;
    if (id == null) return;
    final renamed = await AppDialog.rename(
      context: context,
      title: 'Rename Clip',
      initialValue: clip.name,
    );
    if (renamed == null || !mounted) return;
    await widget.controller.renameClip(id, renamed);
  }

  Future<void> _handleDeleteClip(BuildContext context, AudioClip clip) async {
    final id = clip.id;
    if (id == null) return;
    final confirmed = await AppDialog.confirmDelete(
      context: context,
      title: 'Delete Clip?',
      message: 'Permanently delete "${clip.name}" from this device?',
    );
    if (!confirmed || !mounted) return;
    await widget.controller.deleteClip(id);
  }

  Future<void> _handlePlayClip(
    BuildContext context,
    RecordingSession session,
    AudioClip clip,
  ) {
    return PlayerSheet.show(
      context: context,
      clip: clip,
      sessionName: session.name,
      playerFactory: widget.playerFactory,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (BuildContext context, Widget? _) {
        final ctrl = widget.controller;
        final theme = Theme.of(context);
        final colors = theme.colorScheme;
        final isEmpty = ctrl.folders.isEmpty && ctrl.sessions.isEmpty;

        return Scaffold(
          appBar: CustomAppBar.standard(
            title: 'Library',
            actions: <Widget>[
              IconButton(
                tooltip: 'New Folder',
                onPressed: () => _handleCreateFolder(context),
                icon: const Icon(Icons.create_new_folder_outlined),
              ),
            ],
          ),
          body: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                if (!ctrl.isAtRoot)
                  _BreadcrumbBar(
                    breadcrumbs: ctrl.breadcrumbs,
                    onSelectFolder: ctrl.openFolder,
                  ),
                if (ctrl.errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: Card(
                      color: colors.errorContainer,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(
                          ctrl.errorMessage!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colors.onErrorContainer,
                          ),
                        ),
                      ),
                    ),
                  ),
                Expanded(
                  child: ctrl.isLoading && isEmpty
                      ? const Center(child: CircularProgressIndicator())
                      : isEmpty
                      ? _EmptyLibraryState(
                          isAtRoot: ctrl.isAtRoot,
                          onCreateFolder: () => _handleCreateFolder(context),
                        )
                      : RefreshIndicator(
                          onRefresh: ctrl.load,
                          child: ListView(
                            padding: const EdgeInsets.all(16),
                            children: <Widget>[
                              if (ctrl.folders.isNotEmpty) ...<Widget>[
                                Text(
                                  'Folders',
                                  style: theme.textTheme.labelLarge?.copyWith(
                                    color: colors.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                for (final folder in ctrl.folders) ...<Widget>[
                                  ctrl.isAtRoot
                                      ? FolderTile.root(
                                          folder: folder,
                                          onOpen: () =>
                                              ctrl.openFolder(folder.id),
                                          onRename: () => _handleRenameFolder(
                                            context,
                                            folder,
                                          ),
                                          onMove: () => _handleMoveFolder(
                                            context,
                                            folder,
                                          ),
                                          onDelete: () => _handleDeleteFolder(
                                            context,
                                            folder,
                                          ),
                                        )
                                      : FolderTile.nested(
                                          folder: folder,
                                          onOpen: () =>
                                              ctrl.openFolder(folder.id),
                                          onRename: () => _handleRenameFolder(
                                            context,
                                            folder,
                                          ),
                                          onMove: () => _handleMoveFolder(
                                            context,
                                            folder,
                                          ),
                                          onDelete: () => _handleDeleteFolder(
                                            context,
                                            folder,
                                          ),
                                        ),
                                  const SizedBox(height: 8),
                                ],
                                const SizedBox(height: 12),
                              ],
                              if (ctrl.sessions.isNotEmpty) ...<Widget>[
                                Text(
                                  'Sessions',
                                  style: theme.textTheme.labelLarge?.copyWith(
                                    color: colors.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                for (
                                  var i = 0;
                                  i < ctrl.sessions.length;
                                  i++
                                ) ...<Widget>[
                                  _buildSessionTile(
                                    context,
                                    ctrl.sessions[i],
                                    ctrl.clipsForSession(
                                      ctrl.sessions[i].id ?? -1,
                                    ),
                                    initiallyExpanded: i == 0,
                                  ),
                                  const SizedBox(height: 10),
                                ],
                              ],
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

  Widget _buildSessionTile(
    BuildContext context,
    RecordingSession session,
    List<AudioClip> clips, {
    required bool initiallyExpanded,
  }) {
    if (session.isActive) {
      return SessionTile.active(
        key: ValueKey<String>('session_${session.id}'),
        session: session,
        clips: clips,
        initiallyExpanded: true,
        onPlayClip: (AudioClip c) => _handlePlayClip(context, session, c),
        onRenameSession: () => _handleRenameSession(context, session),
        onMoveSession: () => _handleMoveSession(context, session),
        onDeleteSession: () => _handleDeleteSession(context, session),
        onRenameClip: (AudioClip c) => _handleRenameClip(context, c),
        onDeleteClip: (AudioClip c) => _handleDeleteClip(context, c),
      );
    }

    return SessionTile.completed(
      key: ValueKey<String>('session_${session.id}'),
      session: session,
      clips: clips,
      initiallyExpanded: initiallyExpanded,
      onPlayClip: (AudioClip c) => _handlePlayClip(context, session, c),
      onRenameSession: () => _handleRenameSession(context, session),
      onMoveSession: () => _handleMoveSession(context, session),
      onDeleteSession: () => _handleDeleteSession(context, session),
      onRenameClip: (AudioClip c) => _handleRenameClip(context, c),
      onDeleteClip: (AudioClip c) => _handleDeleteClip(context, c),
    );
  }
}

class _BreadcrumbBar extends StatelessWidget {
  const _BreadcrumbBar({
    required this.breadcrumbs,
    required this.onSelectFolder,
  });

  final List<Folder> breadcrumbs;
  final ValueChanged<int?> onSelectFolder;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colors.surfaceContainer,
        border: Border(bottom: BorderSide(color: colors.outlineVariant)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: <Widget>[
            TextButton.icon(
              onPressed: () => onSelectFolder(null),
              icon: const Icon(Icons.home_outlined, size: 18),
              label: const Text('Library'),
            ),
            for (var i = 0; i < breadcrumbs.length; i++) ...<Widget>[
              Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: colors.onSurfaceVariant,
              ),
              TextButton(
                onPressed: i == breadcrumbs.length - 1
                    ? null
                    : () => onSelectFolder(breadcrumbs[i].id),
                child: Text(
                  breadcrumbs[i].name,
                  style: i == breadcrumbs.length - 1
                      ? theme.textTheme.labelLarge?.copyWith(
                          color: colors.onSurface,
                        )
                      : null,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _EmptyLibraryState extends StatelessWidget {
  const _EmptyLibraryState({
    required this.isAtRoot,
    required this.onCreateFolder,
  });

  final bool isAtRoot;
  final VoidCallback onCreateFolder;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              isAtRoot
                  ? Icons.library_music_outlined
                  : Icons.folder_open_rounded,
              size: 52,
              color: colors.onSurfaceVariant,
            ),
            const SizedBox(height: 12),
            Text(
              isAtRoot ? 'No sessions yet' : 'This folder is empty',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              isAtRoot
                  ? 'Start a recording session and tap the floating button to save audio replay clips.'
                  : 'Create a sub-folder or move sessions into this folder.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onCreateFolder,
              icon: const Icon(Icons.create_new_folder_outlined),
              label: const Text('New Folder'),
            ),
          ],
        ),
      ),
    );
  }
}
