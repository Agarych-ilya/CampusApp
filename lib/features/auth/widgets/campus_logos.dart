import 'package:flutter/material.dart';

// Логотип приложения(и не только - ВУЗы). Всё берётся из папки assets

class CampusLogo extends StatelessWidget {
  const CampusLogo({super.key});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/logo/logo_main.png',
      width: 130,
      height: 105,
      fit: BoxFit.contain,
    );
  }
}
