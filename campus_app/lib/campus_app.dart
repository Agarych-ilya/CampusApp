import 'package:flutter/material.dart';
import 'package:campus_app/core/theme/theme.dart';
import 'package:campus_app/core/router/router.dart';

class CampusApp extends StatelessWidget {
  const CampusApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Campus',
      theme: lightTheme,
      routes: routes,
      initialRoute: '/login', // Первый экран при запуске
      debugShowCheckedModeBanner: false, // Убирает debug-баннер
    );
  }

}