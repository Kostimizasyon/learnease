import 'package:flutter/material.dart';

/// Single source of truth for the Learnese color palette.
/// Native overlay colors are mirrored in android/app/src/main/res/values/colors.xml.
abstract final class AppColors {
  // Primary — Deep Teal
  static const Color primaryLight = Color(0xFF0F766E);
  static const Color onPrimaryLight = Color(0xFFFFFFFF);
  static const Color primaryContainerLight = Color(0xFFCCFBF1);
  static const Color onPrimaryContainerLight = Color(0xFF115E59);

  static const Color primaryDark = Color(0xFF2DD4BF);
  static const Color onPrimaryDark = Color(0xFF042F2E);
  static const Color primaryContainerDark = Color(0xFF134E4A);
  static const Color onPrimaryContainerDark = Color(0xFFCCFBF1);

  // Secondary — Neutral Slate
  static const Color secondaryLight = Color(0xFF475569);
  static const Color onSecondaryLight = Color(0xFFFFFFFF);
  static const Color secondaryContainerLight = Color(0xFFE2E8F0);
  static const Color onSecondaryContainerLight = Color(0xFF1E293B);

  static const Color secondaryDark = Color(0xFF94A3B8);
  static const Color onSecondaryDark = Color(0xFF0F172A);
  static const Color secondaryContainerDark = Color(0xFF1E293B);
  static const Color onSecondaryContainerDark = Color(0xFFE2E8F0);

  // Surfaces & Ink — Light
  static const Color backgroundLight = Color(0xFFF8FAFC);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color surfaceVariantLight = Color(0xFFF1F5F9);
  static const Color onSurfaceLight = Color(0xFF0F172A);
  static const Color onSurfaceMutedLight = Color(0xFF475569);
  static const Color outlineLight = Color(0xFFCBD5E1);
  static const Color outlineSubtleLight = Color(0xFFE2E8F0);

  // Surfaces & Ink — Dark
  static const Color backgroundDark = Color(0xFF0B1115);
  static const Color surfaceDark = Color(0xFF131C22);
  static const Color surfaceVariantDark = Color(0xFF1E2A32);
  static const Color onSurfaceDark = Color(0xFFF1F5F9);
  static const Color onSurfaceMutedDark = Color(0xFF94A3B8);
  static const Color outlineDark = Color(0xFF334155);
  static const Color outlineSubtleDark = Color(0xFF1E293B);

  // Recording & Destructive Accent — reserved for live recording state & delete/dismiss
  static const Color recordingLight = Color(0xFFDC2626);
  static const Color onRecordingLight = Color(0xFFFFFFFF);
  static const Color recordingContainerLight = Color(0xFFFEE2E2);
  static const Color onRecordingContainerLight = Color(0xFF991B1B);

  static const Color recordingDark = Color(0xFFF87171);
  static const Color onRecordingDark = Color(0xFF450A0A);
  static const Color recordingContainerDark = Color(0xFF7F1D1D);
  static const Color onRecordingContainerDark = Color(0xFFFEE2E2);

  // Native Overlay Tokens (kept in sync with android/app/src/main/res/values/colors.xml)
  static const Color overlaySurface = Color(0xCC131C22);
  static const Color overlayBorder = Color(0x662DD4BF);
  static const Color overlayIcon = Color(0xFFF1F5F9);
  static const Color overlayRecordingDot = Color(0xFFEF4444);
  static const Color overlaySaveFlash = Color(0xFF0F766E);
  static const Color overlayDismissBackground = Color(0xD9DC2626);
  static const Color overlayDismissIcon = Color(0xFFFFFFFF);
}
