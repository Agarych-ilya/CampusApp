import 'package:flutter/material.dart';
import '/core/theme/app_theme.dart';

// Универсальное поле ввода для формы
// Используется для имени, почты, пароля и т.д.

class CampusInputField extends StatelessWidget { 
  const CampusInputField({
    super.key,
    required this.hintText,
    this.controller,
    this.obscureText = false,
    this.keyboardType,
    this.suffixIcon,
  });

  final String hintText; // Текст-подсказка внутри поля
  final TextEditingController? controller; // Контроллер для получения текста из поля
  final bool obscureText; // Нужно ли скрывать вводимый текст, для пароля = true
  final TextInputType? keyboardType; // Тип клавиатуры: имя, email, обычный текст и т.д.
  final Widget? suffixIcon; // Иконка справа внутри поля(например: глаз)

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      height: 48,
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        style: TextStyle(
          fontSize: 14, 
          color: theme.colorScheme.onSurface,
        ),
        cursorColor: AppTheme.pink,
        decoration: InputDecoration(
          hintText: hintText, 
          suffixIcon: suffixIcon,
        ),
      ),
    );
  }
}
