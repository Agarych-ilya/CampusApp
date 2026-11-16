import 'package:flutter/material.dart';

/// One restrained palette for CampusApp, based on the provided university
/// application: near-black surfaces, muted lavender accents, precise type.
/// Keep the layout neutral; use purple only for selection and small badges.
abstract final class AppTheme {
  static const Color accent = Color(0xFFA58CFA);
  static const Color accentStrong = Color(0xFF8067D7);
  static const Color cyan = Color(0xFFC4B5FD);
  static const Color ink = Color(0xFF0B0A0E);
  static const Color panel = Color(0xFF18171C);
  static const Color lightBackground = Color(0xFFF8F7FC);
  static const Color darkBackground = ink;
  static const Color lightText = Color(0xFF211F2C);
  static const Color darkText = Color(0xFFF5F4F8);

  // Compatibility aliases for older widgets.
  static const Color pink = accent;
  static const Color orange = cyan;
  static const Color purple = accentStrong;

  static const Color lightFieldBorder = Color(0xFFD8D5E4);
  static const Color darkFieldBorder = Color(0xFF302E36);
  static const Color lightHintText = Color(0xFF797586);
  static const Color darkHintText = Color(0xFF96929F);

  static const LinearGradient mainGradient = LinearGradient(
    colors: [accentStrong, accent],
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
    final surface = dark ? const Color(0xFF17161B) : Colors.white;
    final onSurface = dark ? darkText : lightText;
    final muted = dark ? darkHintText : lightHintText;

    final scheme = ColorScheme.fromSeed(
      seedColor: accentStrong,
      brightness: brightness,
      primary: primary,
      onPrimary: dark ? ink : Colors.white,
      secondary: dark ? cyan : const Color(0xFF7760C5),
      onSecondary: dark ? ink : Colors.white,
      surface: surface,
      onSurface: onSurface,
      onSurfaceVariant: muted,
      surfaceContainerLow:
          dark ? const Color(0xFF111014) : const Color(0xFFF2F0F8),
      surfaceContainer:
          dark ? const Color(0xFF1B1A20) : const Color(0xFFEBE8F3),
      surfaceContainerHigh:
          dark ? const Color(0xFF25232B) : const Color(0xFFE2DFF0),
      outlineVariant:
          dark ? darkFieldBorder : lightFieldBorder,
      // Neutral warm status color only for warnings, never branding.
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
        fillColor: dark ? const Color(0xFF201E27) : Colors.white,
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
