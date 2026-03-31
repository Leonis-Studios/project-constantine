// ─────────────────────────────────────────────────────────────────────────────
// app_theme.dart
//
// PURPOSE: Centralizes every visual decision — colors, text styles, card
//          shapes, and the overall ThemeData — so all screens look consistent.
//
// HOW TO USE: Call AppTheme.buildTheme() once in main.dart and pass the result
//             to MaterialApp's `theme` parameter. Access color constants like
//             AppTheme.positive anywhere in the widget tree.
//
// WHY DARK MODE: Finance apps conventionally use dark backgrounds so that the
//                red/green price indicators pop visually and don't cause eye
//                fatigue during long sessions.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';

class AppTheme {
  // ── Prevent instantiation — this is a static-only utility class ────────────
  AppTheme._();

  // ── Core palette ────────────────────────────────────────────────────────────

  // The deepest background — near-black with a subtle blue undertone.
  static const Color background = Color(0xFF050510);

  // Card and tile surfaces — dark navy, clearly distinct from background.
  static const Color surface = Color(0xFF0D0D1A);

  // Dark indigo — used for badge/chip fills so text stays readable on surfaces.
  static const Color surfaceVariant = Color(0xFF1A1040);

  // Borders, dividers, and muted outlines — subtle purple.
  static const Color border = Color(0xFF2D2B55);

  // Primary interactive accent — neon cyan, the signature cyberpunk color.
  static const Color accent = Color(0xFF00E5FF);

  // ── Semantic price colors ────────────────────────────────────────────────────

  // Green: price went up today, or a positive event — neon green.
  static const Color positive = Color(0xFF00FF9F);

  // Red: price went down today, or a negative event — neon pink/red.
  static const Color negative = Color(0xFFFF2D78);

  // Soft green for backgrounds (e.g., positive badge fill).
  static const Color positiveFaint = Color(0xFF001A0F);

  // Soft red for backgrounds (e.g., negative badge fill).
  static const Color negativeFaint = Color(0xFF1A000D);

  // ── Text colors ─────────────────────────────────────────────────────────────

  // Main readable text — near-white with a slight blue tint for cyberpunk feel.
  static const Color textPrimary = Color(0xFFE0E0FF);

  // Supporting text — muted blue, readable on dark surfaces.
  static const Color textSecondary = Color(0xFF9090C0);

  // Muted/disabled text — dim purple, for timestamps and placeholders.
  static const Color textMuted = Color(0xFF5060A0);

  // ── Shape ───────────────────────────────────────────────────────────────────

  // Standard border radius used on cards, badges, and sheets.
  static const double cardRadius = 12.0;

  // Smaller radius for chips and inline badges.
  static const double badgeRadius = 6.0;

  // ── Text styles ─────────────────────────────────────────────────────────────
  //
  // Use these named styles so that swapping the font later is a one-line change.

  // Large price display (e.g., "$142.50" on the stock detail screen).
  static const TextStyle priceDisplay = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.w700,
    color: textPrimary,
    letterSpacing: -0.5,
  );

  // Ticker symbols — monospace so all tickers align vertically in lists.
  static const TextStyle ticker = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w700,
    color: textPrimary,
    fontFamily: 'monospace',
    letterSpacing: 1.0,
  );

  // Company name — regular weight, slightly muted.
  static const TextStyle companyName = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    color: textSecondary,
  );

  // Section headers and screen titles.
  static const TextStyle headline = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: textPrimary,
  );

  // Card title or row label.
  static const TextStyle label = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w500,
    color: textSecondary,
    letterSpacing: 0.3,
  );

  // Small captions — timestamps, hints, helper text.
  static const TextStyle caption = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w400,
    color: textSecondary,
  );

  // ── ThemeData factory ────────────────────────────────────────────────────────
  //
  // Returns the fully configured ThemeData consumed by MaterialApp in main.dart.
  // Customise sub-themes here rather than scattering theme overrides across
  // individual widgets — keeps widgets clean and theme changes centralised.

  static ThemeData buildTheme() {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      // ignore: deprecated_member_use
      colorScheme: const ColorScheme.dark(
        surface: surface,
        primary: accent,
        error: negative,
        onSurface: textPrimary,
        onPrimary: background,
      ),

      // ── AppBar ─────────────────────────────────────────────────────────────
      appBarTheme: const AppBarTheme(
        backgroundColor: background,
        foregroundColor: textPrimary,
        elevation: 0,
        // Remove the bottom border shadow — we'll use Divider widgets instead.
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
      ),

      // ── Cards ──────────────────────────────────────────────────────────────
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(cardRadius),
          side: const BorderSide(color: border, width: 1),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      ),

      // ── BottomNavigationBar ────────────────────────────────────────────────
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: surface,
        selectedItemColor: accent,
        unselectedItemColor: textMuted,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),

      // ── ElevatedButton ─────────────────────────────────────────────────────
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: background,
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(badgeRadius),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        ),
      ),

      // ── OutlinedButton ─────────────────────────────────────────────────────
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textPrimary,
          side: const BorderSide(color: border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(badgeRadius),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        ),
      ),

      // ── Chip ───────────────────────────────────────────────────────────────
      chipTheme: ChipThemeData(
        backgroundColor: surface,
        labelStyle: label,
        side: const BorderSide(color: border),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(badgeRadius),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      ),

      // ── Divider ────────────────────────────────────────────────────────────
      dividerTheme: const DividerThemeData(
        color: border,
        thickness: 1,
        space: 1,
      ),

      // ── ListTile ───────────────────────────────────────────────────────────
      listTileTheme: const ListTileThemeData(
        tileColor: Colors.transparent,
        iconColor: textSecondary,
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
    );
  }
}
