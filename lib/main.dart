import 'package:flutter/material.dart';

import 'pages/home_page/home_page.dart';
import 'pages/library_page/library_page.dart';
import 'pages/library_page/player_sheet.dart';
import 'services/database_helper.dart';
import 'services/folder_repository.dart';
import 'services/library_controller.dart';
import 'services/permission_service.dart';
import 'services/preferences_service.dart';
import 'services/recorder_channel.dart';
import 'services/session_controller.dart';
import 'services/session_repository.dart';
import 'services/storage_service.dart';
import 'theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const LearneseApp());
}

class LearneseApp extends StatefulWidget {
  const LearneseApp({
    super.key,
    this.sessionController,
    this.libraryController,
    this.libraryBuilder,
    this.playerFactory,
  });

  final SessionController? sessionController;
  final LibraryController? libraryController;
  final WidgetBuilder? libraryBuilder;
  final ClipPlayerFactory? playerFactory;

  @override
  State<LearneseApp> createState() => _LearneseAppState();
}

class _LearneseAppState extends State<LearneseApp> with WidgetsBindingObserver {
  late final SessionController _sessionController;
  LibraryController? _libraryController;
  late final bool _ownsSessionController;
  bool _ownsLibraryController = false;
  DatabaseHelper? _databaseHelper;
  RecorderChannel? _recorderChannel;
  int _currentTab = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final providedSession = widget.sessionController;
    final providedLibrary = widget.libraryController;

    if (providedSession != null) {
      _sessionController = providedSession;
      _ownsSessionController = false;
      _libraryController = providedLibrary;
    } else {
      final dbHelper = DatabaseHelper();
      final storage = StorageService();
      final recorder = RecorderChannel();
      final sessionRepo = SessionRepository(
        databaseHelper: dbHelper,
        storageService: storage,
      );
      final folderRepo = FolderRepository(databaseHelper: dbHelper);
      _databaseHelper = dbHelper;
      _recorderChannel = recorder;
      _sessionController = SessionController(
        recorderChannel: recorder,
        sessionRepository: sessionRepo,
        storageService: storage,
        preferencesService: PreferencesService(),
        permissionService: PermissionService(),
      );
      _ownsSessionController = true;

      if (providedLibrary != null) {
        _libraryController = providedLibrary;
      } else {
        _libraryController = LibraryController(
          sessionRepository: sessionRepo,
          folderRepository: folderRepo,
          sessionController: _sessionController,
        );
        _ownsLibraryController = true;
      }
    }

    _sessionController.onNavigateToActiveSession = _openActiveSessionTab;
    _sessionController.initialize();
  }

  void _openActiveSessionTab() {
    if (!mounted) return;
    if (_currentTab != 0) {
      setState(() => _currentTab = 0);
    }
  }

  void _openLibraryTab() {
    if (!mounted) return;
    _libraryController?.load();
    if (_currentTab != 1) {
      setState(() => _currentTab = 1);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _sessionController.syncWithNative();
      if (_currentTab == 1) {
        _libraryController?.load();
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (_ownsLibraryController) {
      _libraryController?.dispose();
    }
    if (_ownsSessionController) {
      _sessionController.dispose();
      _recorderChannel?.dispose();
      _databaseHelper?.close();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final libraryPage =
        widget.libraryBuilder?.call(context) ??
        (_libraryController != null
            ? LibraryPage(
                controller: _libraryController!,
                playerFactory: widget.playerFactory,
              )
            : const SizedBox.shrink());

    return MaterialApp(
      title: 'Learnese',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      home: Scaffold(
        body: IndexedStack(
          index: _currentTab,
          children: <Widget>[
            HomePage(
              controller: _sessionController,
              onOpenLibrary: _openLibraryTab,
            ),
            libraryPage,
          ],
        ),
        bottomNavigationBar: ListenableBuilder(
          listenable: _sessionController,
          builder: (BuildContext context, Widget? _) {
            return NavigationBar(
              selectedIndex: _currentTab,
              onDestinationSelected: (int index) {
                if (index == 1) {
                  _libraryController?.load();
                }
                setState(() => _currentTab = index);
              },
              destinations: <NavigationDestination>[
                NavigationDestination(
                  icon: Icon(
                    _sessionController.isSessionActive
                        ? Icons.graphic_eq_rounded
                        : Icons.radio_button_checked_rounded,
                  ),
                  label: _sessionController.isSessionActive
                      ? 'Active'
                      : 'Record',
                ),
                const NavigationDestination(
                  icon: Icon(Icons.library_music_outlined),
                  selectedIcon: Icon(Icons.library_music_rounded),
                  label: 'Library',
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
