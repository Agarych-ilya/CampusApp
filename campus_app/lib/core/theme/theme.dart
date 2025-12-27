import 'package:flutter/material.dart';

final lightTheme = ThemeData(
  scaffoldBackgroundColor: const Color.fromARGB(255, 247, 247, 255),
  appBarTheme: const AppBarThemeData(
    backgroundColor: const Color.fromARGB(255, 247, 247, 255),
    titleTextStyle: TextStyle(
      color: Colors.black,
      fontSize: 24,
      fontWeight: FontWeight.w700,
    ),
  ),
    textTheme: TextTheme(
      bodyMedium: TextStyle(
        color: Colors.black,
        fontSize: 16,
        fontWeight: FontWeight.w400,
      )
    )
);