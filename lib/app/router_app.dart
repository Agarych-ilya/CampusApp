import 'package:flutter/material.dart';

import '/features/auth/auth.dart';
import '/features/profile/data/student_profile.dart';
import '/features/profile/data/student_profile_storage.dart';

import 'main_tabs_screen.dart';

class AppRoutes {
  static const String login = '/login';
  static const String main = '/main';
}

class AppRouter {
  static Map<String, WidgetBuilder> routes = {
    // При запуске сначала быстро проверяем,
    // сохранён ли уже профиль пользователя.
    AppRoutes.login: (context) => const _StartupGate(),

    AppRoutes.main: (context) => const MainTabsScreen(),
  };
}

// ============================================================
// STARTUP GATE
//
// Если пользователь уже входил через БАРС
// и профиль сохранён локально:
//
// Campus запускается сразу.
//
// Если профиля нет:
//
// показываем LoginScreen.
// ============================================================

class _StartupGate extends StatefulWidget {
  const _StartupGate();

  @override
  State<_StartupGate> createState() => _StartupGateState();
}

class _StartupGateState extends State<_StartupGate> {
  final StudentProfileStorage _profileStorage = StudentProfileStorage();

  late final Future<StudentProfile?> _profileFuture;

  @override
  void initState() {
    super.initState();

    // Проверяем локальные данные только один раз.
    _profileFuture = _profileStorage.getProfile();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<StudentProfile?>(
      future: _profileFuture,
      builder: (context, snapshot) {
        // =====================================================
        // ПРОФИЛЬ НАЙДЕН
        //
        // Вообще не открываем WebView/BARS.
        // =====================================================

        if (snapshot.connectionState == ConnectionState.done) {
          final profile = snapshot.data;

          if (_isValidProfile(profile)) {
            return const MainTabsScreen();
          }

          // Профиля нет -> обычный первый вход.
          return const LoginScreen();
        }

        // =====================================================
        // Проверка SharedPreferences занимает обычно мгновение.
        //
        // Не показываем WebView и не создаём белый экран.
        // =====================================================

        return const Scaffold(body: SizedBox.expand());
      },
    );
  }

  bool _isValidProfile(StudentProfile? profile) {
    if (profile == null) {
      return false;
    }

    // Группа — минимальный признак того,
    // что авторизация и получение профиля завершились.
    return profile.group.trim().isNotEmpty;
  }
}
