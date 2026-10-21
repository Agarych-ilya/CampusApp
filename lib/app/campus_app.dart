import 'package:flutter/material.dart';

import '/core/theme/app_theme.dart';
import 'router_app.dart';

class CampusApp extends StatelessWidget {
  const CampusApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      initialRoute: AppRoutes.login,
      routes: AppRouter.routes,
    );
  }
}
