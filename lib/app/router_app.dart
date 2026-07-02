import 'package:flutter/material.dart';

import '/features/auth/auth.dart';
import 'main_tabs_screen.dart';

class AppRoutes {
  static const String register = '/register';
  static const String login = '/login';
  static const String forgotPassword = '/forgot-password';
  static const String main = '/main';
  
}

class AppRouter {
  static Map<String, WidgetBuilder> routes = {
    AppRoutes.register:(context) => const RegisterScreen(),
    AppRoutes.login: (context) => const LoginScreen(),
    AppRoutes.forgotPassword:(context) => const ForgotPasswordScreen(),
    AppRoutes.main: (context) => const MainTabsScreen(),
  };

}