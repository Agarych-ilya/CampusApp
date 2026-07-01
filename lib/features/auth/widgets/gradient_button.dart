import 'package:flutter/material.dart';
import '/core/theme/app_theme.dart';


// Кнопка с градиентом 
// Используется для кнопки: "Зарегистрироваться", ...

class GradientButton extends StatelessWidget {
  const GradientButton({
    super.key, 
    required this.text,
    this.onPressed,
    this.isLoading = false,
  });

  final String text; // Текст на кнопке
  final VoidCallback? onPressed; // Функция, которая выполнится при нажатии
  final bool isLoading; // Показывать ли состоянии загрузки

  @override
  Widget build(BuildContext context) {
    final bool isDisabled = onPressed == null || isLoading;
    
    return Opacity(
      opacity: isDisabled ? 0.7: 1,
      child: Container(
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

            onTap: isDisabled ? null : onPressed,
              
            child: Center(
              child: isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
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
      ),
    );
  }
}
