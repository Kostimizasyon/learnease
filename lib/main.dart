import 'package:flutter/material.dart';

import 'theme/app_theme.dart';

void main() {
  runApp(const LearneseApp());
}

class LearneseApp extends StatelessWidget {
  const LearneseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Learnese',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      home: const _BootstrapHomePage(),
    );
  }
}

// TODO(chunk-5): Replace bootstrap shell with HomePage and LibraryPage navigation.
class _BootstrapHomePage extends StatelessWidget {
  const _BootstrapHomePage();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Learnese')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                Icons.graphic_eq_rounded,
                size: 56,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text('Learnese', style: theme.textTheme.headlineMedium),
              const SizedBox(height: 8),
              Text(
                'Instant replay for your device audio output.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
