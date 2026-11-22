import 'package:flutter/material.dart';

import 'app_colors.dart';

@immutable
class AppRecordingColors extends ThemeExtension<AppRecordingColors> {
  const AppRecordingColors({
    required this.recording,
    required this.onRecording,
    required this.recordingContainer,
    required this.onRecordingContainer,
  });

  const AppRecordingColors.light()
    : recording = AppColors.recordingLight,
      onRecording = AppColors.onRecordingLight,
      recordingContainer = AppColors.recordingContainerLight,
      onRecordingContainer = AppColors.onRecordingContainerLight;

  const AppRecordingColors.dark()
    : recording = AppColors.recordingDark,
      onRecording = AppColors.onRecordingDark,
      recordingContainer = AppColors.recordingContainerDark,
      onRecordingContainer = AppColors.onRecordingContainerDark;

  final Color recording;
  final Color onRecording;
  final Color recordingContainer;
  final Color onRecordingContainer;

  @override
  AppRecordingColors copyWith({
    Color? recording,
    Color? onRecording,
    Color? recordingContainer,
    Color? onRecordingContainer,
  }) {
    return AppRecordingColors(
      recording: recording ?? this.recording,
      onRecording: onRecording ?? this.onRecording,
      recordingContainer: recordingContainer ?? this.recordingContainer,
      onRecordingContainer: onRecordingContainer ?? this.onRecordingContainer,
    );
  }

  @override
  AppRecordingColors lerp(AppRecordingColors? other, double t) {
    if (other is! AppRecordingColors) {
      return this;
    }
    return AppRecordingColors(
      recording: Color.lerp(recording, other.recording, t) ?? recording,
      onRecording: Color.lerp(onRecording, other.onRecording, t) ?? onRecording,
      recordingContainer:
          Color.lerp(recordingContainer, other.recordingContainer, t) ??
          recordingContainer,
      onRecordingContainer:
          Color.lerp(onRecordingContainer, other.onRecordingContainer, t) ??
          onRecordingContainer,
    );
  }
}

abstract final class AppTheme {
  static ThemeData light() {
    const colorScheme = ColorScheme(
      brightness: Brightness.light,
      primary: AppColors.primaryLight,
      onPrimary: AppColors.onPrimaryLight,
      primaryContainer: AppColors.primaryContainerLight,
      onPrimaryContainer: AppColors.onPrimaryContainerLight,
      secondary: AppColors.secondaryLight,
      onSecondary: AppColors.onSecondaryLight,
      secondaryContainer: AppColors.secondaryContainerLight,
      onSecondaryContainer: AppColors.onSecondaryContainerLight,
      error: AppColors.recordingLight,
      onError: AppColors.onRecordingLight,
      errorContainer: AppColors.recordingContainerLight,
      onErrorContainer: AppColors.onRecordingContainerLight,
      surface: AppColors.surfaceLight,
      onSurface: AppColors.onSurfaceLight,
      onSurfaceVariant: AppColors.onSurfaceMutedLight,
      surfaceContainerLowest: AppColors.surfaceLight,
      surfaceContainerLow: AppColors.backgroundLight,
      surfaceContainer: AppColors.surfaceVariantLight,
      surfaceContainerHigh: AppColors.outlineSubtleLight,
      surfaceContainerHighest: AppColors.outlineLight,
      outline: AppColors.outlineLight,
      outlineVariant: AppColors.outlineSubtleLight,
    );

    return _buildTheme(
      colorScheme: colorScheme,
      scaffoldBackground: AppColors.backgroundLight,
      recordingColors: const AppRecordingColors.light(),
    );
  }

  static ThemeData dark() {
    const colorScheme = ColorScheme(
      brightness: Brightness.dark,
      primary: AppColors.primaryDark,
      onPrimary: AppColors.onPrimaryDark,
      primaryContainer: AppColors.primaryContainerDark,
      onPrimaryContainer: AppColors.onPrimaryContainerDark,
      secondary: AppColors.secondaryDark,
      onSecondary: AppColors.onSecondaryDark,
      secondaryContainer: AppColors.secondaryContainerDark,
      onSecondaryContainer: AppColors.onSecondaryContainerDark,
      error: AppColors.recordingDark,
      onError: AppColors.onRecordingDark,
      errorContainer: AppColors.recordingContainerDark,
      onErrorContainer: AppColors.onRecordingContainerDark,
      surface: AppColors.surfaceDark,
      onSurface: AppColors.onSurfaceDark,
      onSurfaceVariant: AppColors.onSurfaceMutedDark,
      surfaceContainerLowest: AppColors.backgroundDark,
      surfaceContainerLow: AppColors.surfaceDark,
      surfaceContainer: AppColors.surfaceVariantDark,
      surfaceContainerHigh: AppColors.outlineSubtleDark,
      surfaceContainerHighest: AppColors.outlineDark,
      outline: AppColors.outlineDark,
      outlineVariant: AppColors.outlineSubtleDark,
    );

    return _buildTheme(
      colorScheme: colorScheme,
      scaffoldBackground: AppColors.backgroundDark,
      recordingColors: const AppRecordingColors.dark(),
    );
  }

  static ThemeData _buildTheme({
    required ColorScheme colorScheme,
    required Color scaffoldBackground,
    required AppRecordingColors recordingColors,
  }) {
    final borderRadius = BorderRadius.circular(14);

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: scaffoldBackground,
      extensions: <ThemeExtension<dynamic>>[recordingColors],
      appBarTheme: AppBarTheme(
        backgroundColor: scaffoldBackground,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: colorScheme.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: colorScheme.outlineVariant),
        ),
        margin: EdgeInsets.zero,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: colorScheme.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: colorScheme.outlineVariant),
        ),
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: colorScheme.onSurface,
        ),
        contentTextStyle: TextStyle(
          fontSize: 14,
          height: 1.45,
          color: colorScheme.onSurfaceVariant,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 48),
          shape: RoundedRectangleBorder(borderRadius: borderRadius),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 48),
          shape: RoundedRectangleBorder(borderRadius: borderRadius),
          side: BorderSide(color: colorScheme.outlineVariant),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: const StadiumBorder(),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceContainer,
        border: OutlineInputBorder(
          borderRadius: borderRadius,
          borderSide: BorderSide(color: colorScheme.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: borderRadius,
          borderSide: BorderSide(color: colorScheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: borderRadius,
          borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: colorScheme.outlineVariant,
        thickness: 1,
        space: 1,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: colorScheme.surface,
        indicatorColor: colorScheme.primaryContainer,
      ),
    );
  }
}
