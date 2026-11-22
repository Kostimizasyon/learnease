import 'package:flutter/material.dart';

import 'pages/home_page/home_page.dart';
import 'pages/util/custom_app_bar.dart';
import 'services/database_helper.dart';
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
  const LearneseApp({super.key, this.sessionController, this.libraryBuilder});

  final SessionController? sessionController;
  final WidgetBuilder? libraryBuilder;

  @override
  State<LearneseApp> createState() => _LearneseAppState();
}

class _LearneseAppState extends State<LearneseApp> {
  late final SessionController _sessionController;
  late final bool _ownsController;
  DatabaseHelper? _databaseHelper;
  RecorderChannel? _recorderChannel;
  int _currentTab = 0;

  @override
  void initState() {
    super.initState();
    final provided = widget.sessionController;
    if (provided != null) {
      _sessionController = provided;
      _ownsController = false;
    } else {
      final dbHelper = DatabaseHelper();
      final storage = StorageService();
      final recorder = RecorderChannel();
      _databaseHelper = dbHelper;
      _recorderChannel = recorder;
      _sessionController = SessionController(
        recorderChannel: recorder,
        sessionRepository: SessionRepository(
          databaseHelper: dbHelper,
          storageService: storage,
        ),
        storageService: storage,
        preferencesService: PreferencesService(),
        permissionService: PermissionService(),
      );
      _ownsController = true;
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
    if (_currentTab != 1) {
      setState(() => _currentTab = 1);
    }
  }

  @override
  void dispose() {
    if (_ownsController) {
      _sessionController.dispose();
      _recorderChannel?.dispose();
      _databaseHelper?.close();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
            widget.libraryBuilder?.call(context) ??
                const _LibraryPlaceholderPage(),
          ],
        ),
        bottomNavigationBar: ListenableBuilder(
          listenable: _sessionController,
          builder: (BuildContext context, Widget? _) {
            return NavigationBar(
              selectedIndex: _currentTab,
              onDestinationSelected: (int index) {
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

// TODO(chunk-6): Replace placeholder with LibraryPage (sessions, folders, playback).
class _LibraryPlaceholderPage extends StatelessWidget {
  const _LibraryPlaceholderPage();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: const CustomAppBar.standard(title: 'Library'),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Saved sessions and clips will appear here.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}
