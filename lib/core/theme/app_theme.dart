import 'package:flutter/material.dart';

/// One restrained palette for CampusApp, based on the provided university
/// application: graphite surfaces, icy blue accents and confident type.
/// No pink/red branding colors are used in the app theme.
abstract final class AppTheme {
  static const Color accent = Color(0xFF9FC2FF);
  static const Color accentStrong = Color(0xFF4C85D9);
  static const Color cyan = Color(0xFF8EDCE6);
  static const Color ink = Color(0xFF0C1018);
  static const Color panel = Color(0xFF171D28);
  static const Color lightBackground = Color(0xFFF5F7FB);
  static const Color darkBackground = ink;
  static const Color lightText = Color(0xFF192435);
  static const Color darkText = Color(0xFFF0F4FC);

  // Compatibility aliases for older widgets, all mapped to cool tones.
  static const Color pink = accent;
  static const Color orange = cyan;
  static const Color purple = accentStrong;

  static const Color lightFieldBorder = Color(0xFFDCE3EF);
  static const Color darkFieldBorder = Color(0xFF303949);
  static const Color lightHintText = Color(0xFF708198);
  static const Color darkHintText = Color(0xFF96A5BA);

  static const LinearGradient mainGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [accentStrong, accent, cyan],
  );
  static const LinearGradient buttonGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [accentStrong, accent],
  );

  static ThemeData get lightTheme => _build(Brightness.light);
  static ThemeData get darkTheme => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final primary = dark ? accent : accentStrong;
    final bg = dark ? darkBackground : lightBackground;
    final surface = dark ? const Color(0xFF151B26) : Colors.white;
    final onSurface = dark ? darkText : lightText;
    final muted = dark ? darkHintText : lightHintText;

    final scheme = ColorScheme.fromSeed(
      seedColor: accentStrong,
      brightness: brightness,
      primary: primary,
      onPrimary: dark ? ink : Colors.white,
      secondary: dark ? cyan : const Color(0xFF357F97),
      onSecondary: dark ? ink : Colors.white,
      surface: surface,
      onSurface: onSurface,
      onSurfaceVariant: muted,
      surfaceContainerLow:
          dark ? const Color(0xFF121823) : const Color(0xFFF1F4FA),
      surfaceContainer:
          dark ? const Color(0xFF1C2431) : const Color(0xFFE9EEF7),
      surfaceContainerHigh:
          dark ? const Color(0xFF253043) : const Color(0xFFDFE7F2),
      outlineVariant:
          dark ? darkFieldBorder : lightFieldBorder,
      // Status colors are cooler and legible, not bright pink or red.
      error: dark ? const Color(0xFFE8C18B) : const Color(0xFFA3682A),
      onError: dark ? ink : Colors.white,
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: bg,
      colorScheme: scheme,
      fontFamily: 'Roboto',
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: AppBarTheme(
        backgroundColor: bg,
        foregroundColor: onSurface,
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          color: onSurface, fontWeight: FontWeight.w800,
          fontSize: 19, letterSpacing: -0.45,
        ),
      ),
      textTheme: TextTheme(
        headlineMedium: TextStyle(
          color: onSurface, fontWeight: FontWeight.w800,
          fontSize: 29, letterSpacing: -0.8,
        ),
        titleLarge: TextStyle(
          color: onSurface, fontWeight: FontWeight.w800,
          fontSize: 23, letterSpacing: -0.55,
        ),
        titleMedium: TextStyle(
          color: onSurface, fontWeight: FontWeight.w700,
          fontSize: 16, letterSpacing: -0.2,
        ),
        titleSmall: TextStyle(
          color: onSurface, fontWeight: FontWeight.w700, fontSize: 14,
        ),
        bodyLarge: TextStyle(
          color: onSurface, fontSize: 16, fontWeight: FontWeight.w500,
        ),
        bodyMedium: TextStyle(
          color: onSurface, fontSize: 14, fontWeight: FontWeight.w500,
        ),
        bodySmall: TextStyle(
          color: muted, fontSize: 12, fontWeight: FontWeight.w500,
        ),
        labelLarge: TextStyle(
          color: onSurface, fontSize: 14, fontWeight: FontWeight.w700,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: dark ? const Color(0xFF1A2331) : Colors.white,
        hintStyle: TextStyle(
          color: muted, fontSize: 14, fontWeight: FontWeight.w500,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18, vertical: 15,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(17),
          borderSide: BorderSide(
            color: dark ? darkFieldBorder : lightFieldBorder,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(17),
          borderSide: BorderSide(color: primary, width: 1.5),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: Colors.transparent, thickness: 0, space: 0,
      ),
    );
    return base;
  }
}
