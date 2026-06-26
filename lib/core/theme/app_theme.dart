import 'package:flutter/material.dart';

class AppTheme {
  static const Color pink = Color(0xFFFF007A);
  static const Color orange = Color(0xFFFF8A00);
  static const Color purple = Color(0xFF7A22FF);

  static const Color lightBackground = Colors.white;
  static const Color darkBackground = Color(0xFF111111);

  static const Color lightText = Colors.black;
  static const Color darkText = Colors.white;

  static const Color lightFieldBorder = Color(0xFFE4E4E4);
  static const Color darkFieldBorder = Color(0xFF3A3A3A);

  static const Color lightHintText = Color(0xFFB8B8B8);
  static const Color darkHintText = Color(0xFF8A8A8A);

  static const LinearGradient mainGradient = LinearGradient(
    colors: [orange, pink, purple],
  );

  static const LinearGradient buttonGradient = LinearGradient(
    colors: [pink, pink, orange],
  );

  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: lightBackground,
    fontFamily: 'Roboto',
    colorScheme: ColorScheme.fromSeed(
      seedColor: pink,
      brightness: Brightness.light,
      primary: pink,
      secondary: orange,
      surface: lightBackground,
    ),
    textTheme: const TextTheme(
      bodyLarge: TextStyle(color: lightText),
      bodyMedium: TextStyle(color: lightText),
      bodySmall: TextStyle(color: lightText),
      titleLarge: TextStyle(color: lightText),
      titleMedium: TextStyle(color: lightText),
      titleSmall: TextStyle(color: lightText),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: lightBackground,
      hintStyle: const TextStyle(
        color: lightHintText,
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(11),
        borderSide: const BorderSide(color: lightFieldBorder, width: 1.4),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(11),
        borderSide: const BorderSide(color: pink, width: 1.5),
      ),
    ),
  );

  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: darkBackground,
    fontFamily: 'Roboto',
    colorScheme: ColorScheme.fromSeed(
      seedColor: pink,
      brightness: Brightness.dark,
      primary: pink,
      secondary: orange,
      surface: darkBackground,
    ),
    textTheme: const TextTheme(
      bodyLarge: TextStyle(color: darkText),
      bodyMedium: TextStyle(color: darkText),
      bodySmall: TextStyle(color: darkText),
      titleLarge: TextStyle(color: darkText),
      titleMedium: TextStyle(color: darkText),
      titleSmall: TextStyle(color: darkText),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFF1A1A1A),
      hintStyle: const TextStyle(
        color: darkHintText,
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(11),
        borderSide: const BorderSide(color: darkFieldBorder, width: 1.4),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(11),
        borderSide: const BorderSide(color: pink, width: 1.5),
      ),
    ),
  );
}
