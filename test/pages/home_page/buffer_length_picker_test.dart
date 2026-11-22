import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learnese/pages/home_page/util/buffer_length_picker.dart';
import 'package:learnese/theme/app_theme.dart';

void main() {
  Widget wrap(Widget child) {
    return MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(
        body: Padding(padding: const EdgeInsets.all(16), child: child),
      ),
    );
  }

  group('BufferLengthPicker', () {
    testWidgets('renders presets and triggers onChanged on preset tap', (
      WidgetTester tester,
    ) async {
      var selected = 30;

      await tester.pumpWidget(
        wrap(
          StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
              return BufferLengthPicker(
                selectedSeconds: selected,
                onChanged: (int value) => setState(() => selected = value),
              );
            },
          ),
        ),
      );

      expect(find.text('15s'), findsOneWidget);
      expect(find.text('30s'), findsOneWidget);
      expect(find.text('60s'), findsOneWidget);
      expect(find.text('120s'), findsOneWidget);
      expect(find.text('Custom'), findsOneWidget);

      await tester.tap(find.text('60s'));
      await tester.pumpAndSettle();

      expect(selected, 60);
    });

    testWidgets('custom dialog validates 1..180 range and updates chip label', (
      WidgetTester tester,
    ) async {
      var selected = 30;

      await tester.pumpWidget(
        wrap(
          StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
              return BufferLengthPicker(
                selectedSeconds: selected,
                onChanged: (int value) => setState(() => selected = value),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Custom'));
      await tester.pumpAndSettle();

      // Enter out-of-range value (>180s cap).
      await tester.enterText(find.byType(TextField), '250');
      await tester.tap(find.text('Set'));
      await tester.pumpAndSettle();

      expect(find.textContaining('between 1 and 180'), findsOneWidget);
      expect(selected, 30);

      // Enter valid custom value.
      await tester.enterText(find.byType(TextField), '45');
      await tester.tap(find.text('Set'));
      await tester.pumpAndSettle();

      expect(selected, 45);
      expect(find.text('Custom (45s)'), findsOneWidget);
    });
  });
}
