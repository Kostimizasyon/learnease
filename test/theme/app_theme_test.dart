import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learnese/theme/app_colors.dart';
import 'package:learnese/theme/app_theme.dart';

void main() {
  group('AppTheme', () {
    test(
      'light theme configures Material 3 palette and recording extension',
      () {
        final theme = AppTheme.light();
        final recording = theme.extension<AppRecordingColors>();

        expect(theme.useMaterial3, isTrue);
        expect(theme.brightness, Brightness.light);
        expect(theme.textTheme.bodyMedium?.fontFamily, AppTheme.fontFamily);
        expect(theme.colorScheme.primary, AppColors.primaryLight);
        expect(theme.scaffoldBackgroundColor, AppColors.backgroundLight);
        expect(recording, isNotNull);
        expect(recording!.recording, AppColors.recordingLight);
      },
    );

    test(
      'dark theme configures Material 3 palette and recording extension',
      () {
        final theme = AppTheme.dark();
        final recording = theme.extension<AppRecordingColors>();

        expect(theme.useMaterial3, isTrue);
        expect(theme.brightness, Brightness.dark);
        expect(theme.textTheme.bodyMedium?.fontFamily, AppTheme.fontFamily);
        expect(theme.colorScheme.primary, AppColors.primaryDark);
        expect(theme.scaffoldBackgroundColor, AppColors.backgroundDark);
        expect(recording, isNotNull);
        expect(recording!.recording, AppColors.recordingDark);
      },
    );

    test('AppRecordingColors supports copyWith and lerp', () {
      const light = AppRecordingColors.light();
      const dark = AppRecordingColors.dark();

      final copied = light.copyWith(recording: AppColors.overlayRecordingDot);
      expect(copied.recording, AppColors.overlayRecordingDot);
      expect(copied.onRecording, light.onRecording);

      final mid = light.lerp(dark, 0.5);
      expect(mid.recording, Color.lerp(light.recording, dark.recording, 0.5));
      expect(light.lerp(null, 0.5), light);
    });
  });
}
