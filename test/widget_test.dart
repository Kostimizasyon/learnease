import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learnese/main.dart';
import 'package:learnese/theme/app_theme.dart';

void main() {
  testWidgets(
    'LearneseApp renders bootstrap shell with light and dark themes',
    (WidgetTester tester) async {
      await tester.pumpWidget(const LearneseApp());

      final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(materialApp.title, 'Learnese');
      expect(materialApp.themeMode, ThemeMode.system);
      expect(materialApp.theme?.extension<AppRecordingColors>(), isNotNull);
      expect(materialApp.darkTheme?.extension<AppRecordingColors>(), isNotNull);

      expect(find.text('Learnese'), findsWidgets);
      expect(
        find.text('Instant replay for your device audio output.'),
        findsOneWidget,
      );
    },
  );
}
