import 'package:flutter/material.dart';
import '/core/theme/app_theme.dart';


// Кнопка с градиентом 
// Используется для кнопки: "Зарегистрироваться", ...

class GradientButton extends StatelessWidget {
  const GradientButton({super.key, required this.text});

  final String text; // Текст на кнопке

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 210,
      height: 44,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: AppTheme.buttonGradient,

        // Тень под кнопкой
        boxShadow: const [
          BoxShadow(
            color: Color(0x40FF007A),
            blurRadius: 14,
            offset: Offset(0, 7),
          ),
        ],
      ),

      // Material и InkWell для эффекта нажатия
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: () {
            // Здесь потом будет логика регистрации.
          },
          child: Center(
            child: Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
