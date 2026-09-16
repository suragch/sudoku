import 'package:flutter/material.dart';

class SudokuTheme {
  // Light Mode Colors
  static const Color lightGridBorderThick = Color(0xFF1E293B); // Slate 800
  static const Color lightGridBorderThin = Color(0xFFCBD5E1); // Slate 300
  static const Color lightSelectedCell = Color(0xFFBFDBFE); // Blue 200
  static const Color lightSameNumber = Color(0xFFDBEAFE); // Blue 100
  static const Color lightCrosshair = Color(0xFFF1F5F9); // Slate 100
  static const Color lightClueText = Color(0xFF0F172A); // Slate 900
  static const Color lightUserText = Color(0xFF2563EB); // Blue 600
  static const Color lightHintText = Color(0xFF059669); // Emerald 600
  static const Color lightErrorBg = Color(0xFFFEE2E2); // Red 100
  static const Color lightErrorText = Color(0xFFDC2626); // Red 600
  static const Color lightCompletionGlow = Color(0xFFFEF08A); // Yellow 200
  static const Color lightHintTargetBg = Color(0xFFFEF3C7); // Amber 100
  static const Color lightHintTargetBorder = Color(0xFFF59E0B); // Amber 500
  static const Color lightHintCauseBg = Color(0xFFEDE9FE); // Violet 100
  static const Color lightHintCauseBorder = Color(0xFF8B5CF6); // Violet 500

  // Dark Mode Colors
  static const Color darkGridBorderThick = Color(0xFF94A3B8); // Slate 400
  static const Color darkGridBorderThin = Color(0xFF334155); // Slate 700
  static const Color darkSelectedCell = Color(0xFF1E3A8A); // Blue 900
  static const Color darkSameNumber = Color(0xFF1E293B); // Slate 800
  static const Color darkCrosshair = Color(0xFF182234);
  static const Color darkClueText = Color(0xFFF8FAFC); // Slate 50
  static const Color darkUserText = Color(0xFF60A5FA); // Blue 400
  static const Color darkHintText = Color(0xFF34D399); // Emerald 400
  static const Color darkErrorBg = Color(0xFF7F1D1D); // Red 900
  static const Color darkErrorText = Color(0xFFF87171); // Red 400
  static const Color darkCompletionGlow = Color(0xFF854D0E); // Amber 800
  static const Color darkHintTargetBg = Color(0xFF451A03); // Amber 950
  static const Color darkHintTargetBorder = Color(0xFFFBBF24); // Amber 400
  static const Color darkHintCauseBg = Color(0xFF2E1065); // Violet 950
  static const Color darkHintCauseBorder = Color(0xFFA78BFA); // Violet 400

  static Color getThickBorder(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? darkGridBorderThick
          : lightGridBorderThick;

  static Color getThinBorder(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? darkGridBorderThin
          : lightGridBorderThin;

  static Color getSelectedCellBg(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? darkSelectedCell
          : lightSelectedCell;

  static Color getSameNumberBg(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? darkSameNumber
          : lightSameNumber;

  static Color getCrosshairBg(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? darkCrosshair
          : lightCrosshair;

  static Color getClueColor(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? darkClueText
          : lightClueText;

  static Color getUserColor(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? darkUserText
          : lightUserText;

  static Color getHintColor(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? darkHintText
          : lightHintText;

  static Color getErrorBg(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? darkErrorBg
          : lightErrorBg;

  static Color getErrorColor(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? darkErrorText
          : lightErrorText;

  static Color getCompletionGlow(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? darkCompletionGlow
          : lightCompletionGlow;

  static Color getHintTargetBg(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? darkHintTargetBg
          : lightHintTargetBg;

  static Color getHintTargetBorder(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? darkHintTargetBorder
          : lightHintTargetBorder;

  static Color getHintCauseBg(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? darkHintCauseBg
          : lightHintCauseBg;

  static Color getHintCauseBorder(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? darkHintCauseBorder
          : lightHintCauseBorder;
}
