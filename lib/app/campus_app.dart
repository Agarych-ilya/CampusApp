import 'package:flutter/material.dart';
import '/core/theme/app_theme.dart';
import '/features/auth/auth.dart';



class CampusApp extends StatelessWidget {
  const CampusApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Campus',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.dark, // Переключение темы
      home: const RegisterScreen(),
    );
  }
}
