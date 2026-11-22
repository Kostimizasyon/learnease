import 'package:flutter/foundation.dart';

import '../data_models/audio_clip.dart';
import '../data_models/folder.dart';
import '../data_models/recording_session.dart';
import 'folder_repository.dart';
import 'session_controller.dart';
import 'session_repository.dart';

/// Coordinates folder navigation, session/clip browsing, and organization actions
/// for [LibraryPage] using standard [ChangeNotifier].
class LibraryController extends ChangeNotifier {
  LibraryController({
    required this._sessionRepository,
    required this._folderRepository,
    this._sessionController,
  }) {
    _sessionController?.addListener(_onSessionStateChanged);
  }

  final SessionRepository _sessionRepository;
  final FolderRepository _folderRepository;
  final SessionController? _sessionController;

  int? _currentFolderId;
  List<Folder> _breadcrumbs = const <Folder>[];
  List<Folder> _folders = const <Folder>[];
  List<Folder> _allFolders = const <Folder>[];
  List<RecordingSession> _sessions = const <RecordingSession>[];
  Map<int, List<AudioClip>> _clipsBySession = const <int, List<AudioClip>>{};
  bool _isLoading = false;
  bool _disposed = false;
  String? _errorMessage;

  int? _lastObservedClipCount;
  bool? _lastObservedActive;

  int? get currentFolderId => _currentFolderId;
  List<Folder> get breadcrumbs => _breadcrumbs;
  List<Folder> get folders => _folders;
  List<Folder> get allFolders => _allFolders;
  List<RecordingSession> get sessions => _sessions;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isAtRoot => _currentFolderId == null;

  List<AudioClip> clipsForSession(int sessionId) =>
      _clipsBySession[sessionId] ?? const <AudioClip>[];

  Future<void> load() async {
    _isLoading = true;
    _errorMessage = null;
    _notifySafe();

    try {
      final folderId = _currentFolderId;
      final results = await Future.wait<Object>(<Future<Object>>[
        _folderRepository.listFolders(
          parentId: folderId,
          rootOnly: folderId == null,
        ),
        _sessionRepository.listSessions(
          folderId: folderId,
          rootOnly: folderId == null,
        ),
        _folderRepository.listFolders(),
        if (folderId != null)
          _folderRepository.getBreadcrumbs(folderId)
        else
          Future<List<Folder>>.value(const <Folder>[]),
      ]);

      final childFolders = results[0] as List<Folder>;
      final sessions = results[1] as List<RecordingSession>;
      final allFolders = results[2] as List<Folder>;
      final breadcrumbs = results[3] as List<Folder>;

      // If current folder was deleted externally, fall back to root.
      if (folderId != null && breadcrumbs.isEmpty) {
        _currentFolderId = null;
        await load();
        return;
      }

      final clipMap = <int, List<AudioClip>>{};
      for (final session in sessions) {
        final id = session.id;
        if (id != null) {
          clipMap[id] = await _sessionRepository.listClipsForSession(id);
        }
      }

      _folders = childFolders;
      _sessions = sessions;
      _allFolders = allFolders;
      _breadcrumbs = breadcrumbs;
      _clipsBySession = clipMap;
    } catch (e) {
      _errorMessage = 'Failed to load library: $e';
    } finally {
      _isLoading = false;
      _notifySafe();
    }
  }

  Future<void> openFolder(int? folderId) async {
    if (_currentFolderId == folderId) return;
    _currentFolderId = folderId;
    await load();
  }

  Future<void> createFolder(String name) async {
    final parentId = _currentFolderId;
    final folder = parentId == null
        ? Folder.root(name: name)
        : Folder.nested(name: name, parentId: parentId);
    await _folderRepository.createFolder(folder);
    await load();
  }

  Future<void> renameFolder(int folderId, String newName) async {
    await _folderRepository.renameFolder(folderId, newName);
    await load();
  }

  Future<void> moveFolder(int folderId, {int? newParentId}) async {
    await _folderRepository.moveFolder(folderId, newParentId: newParentId);
    await load();
  }

  Future<void> deleteFolder(int folderId) async {
    final current = _currentFolderId;
    if (current == folderId) {
      final folder = await _folderRepository.getFolder(folderId);
      _currentFolderId = folder?.parentId;
    }
    await _folderRepository.deleteFolder(folderId);
    await load();
  }

  Future<void> renameSession(int sessionId, String newName) async {
    await _sessionRepository.renameSession(sessionId, newName);
    await load();
  }

  Future<void> moveSession(int sessionId, {int? folderId}) async {
    await _sessionRepository.moveSession(sessionId, folderId: folderId);
    await load();
  }

  Future<void> deleteSession(int sessionId) async {
    await _sessionRepository.deleteSession(sessionId);
    await load();
  }

  Future<void> renameClip(int clipId, String newName) async {
    await _sessionRepository.renameClip(clipId, newName);
    await load();
  }

  Future<void> deleteClip(int clipId) async {
    await _sessionRepository.deleteClip(clipId);
    await load();
  }

  /// Returns [folderId] plus all of its descendant folder IDs so the move picker
  /// cannot offer invalid self/descendant targets.
  Set<int> excludedMoveTargetsForFolder(int folderId) {
    final excluded = <int>{folderId};
    var added = true;
    while (added) {
      added = false;
      for (final folder in _allFolders) {
        final id = folder.id;
        if (id != null &&
            folder.parentId != null &&
            excluded.contains(folder.parentId) &&
            excluded.add(id)) {
          added = true;
        }
      }
    }
    return excluded;
  }

  void _onSessionStateChanged() {
    final controller = _sessionController;
    if (controller == null) return;

    final active = controller.isSessionActive;
    final clipCount = controller.activeClipCount;
    if (active != _lastObservedActive || clipCount != _lastObservedClipCount) {
      _lastObservedActive = active;
      _lastObservedClipCount = clipCount;
      load();
    }
  }

  void _notifySafe() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _sessionController?.removeListener(_onSessionStateChanged);
    super.dispose();
  }
}
