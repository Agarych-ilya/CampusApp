import 'package:flutter/material.dart';


// Widget для текста с градиентом
// Сейчас используется для надписи CAMPUS

class GradientText extends StatelessWidget {
  const GradientText(
    this.text, {
    super.key,
    required this.gradient,
    required this.style,
  });

  final String text; // Сам текст
  final Gradient gradient; // Градиент, которым будет окрашен текст
  final TextStyle style; // Стиль текста: размер, жирность, расстояние между буквами

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (bounds) {
        return gradient.createShader(
          Rect.fromLTWH(0, 0, bounds.width, bounds.height),
        );
      },

      // Сам текст. Цвет ставим белым, потому что поверх него накладывается ShaderMask
      child: Text(text, style: style.copyWith(color: Colors.white)),
    );
  }
}
