import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool _passwordHidden = true;
  bool _repeatPasswordHidden = true;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = theme.colorScheme.onSurface;
    final secondaryTextColor = theme.colorScheme.onSurfaceVariant;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const GradientText(
                    'CAMPUS',
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.5,
                    ),
                    gradient: AppTheme.mainGradient,
                  ),

                  const SizedBox(height: 18),

                  const CampusLogo(),

                  const SizedBox(height: 20),

                  Text(
                    'Сделано студентами для студентов',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: textColor,
                    ),
                  ),

                  const SizedBox(height: 28),

                  Text(
                    'Регистрация',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: textColor,
                    ),
                  ),

                  const SizedBox(height: 18),

                  const CampusInputField(
                    hintText: 'name surname',
                    keyboardType: TextInputType.name,
                  ),

                  const SizedBox(height: 14),

                  const CampusInputField(
                    hintText: 'student@mpei.ru',
                    keyboardType: TextInputType.emailAddress,
                  ),

                  const SizedBox(height: 14),

                  CampusInputField(
                    hintText: 'password',
                    obscureText: _passwordHidden,
                    suffixIcon: IconButton(
                      onPressed: () {
                        setState(() {
                          _passwordHidden = !_passwordHidden;
                        });
                      },
                      icon: Icon(
                        _passwordHidden
                            ? Icons.visibility
                            : Icons.visibility_off,
                        color: secondaryTextColor,
                      ),
                    ),
                  ),

                  const SizedBox(height: 14),

                  CampusInputField(
                    hintText: 'repeat password',
                    obscureText: _repeatPasswordHidden,
                    suffixIcon: IconButton(
                      onPressed: () {
                        setState(() {
                          _repeatPasswordHidden = !_repeatPasswordHidden;
                        });
                      },
                      icon: Icon(
                        _repeatPasswordHidden
                            ? Icons.visibility
                            : Icons.visibility_off,
                        color: secondaryTextColor,
                      ),
                    ),
                  ),

                  const SizedBox(height: 22),

                  const GradientButton(text: 'Зарегистрироваться'),

                  const SizedBox(height: 16),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Уже есть аккаунт? ',
                        style: TextStyle(
                          fontSize: 13,
                          color: secondaryTextColor,
                        ),
                      ),
                      GestureDetector(
                        onTap: () {},
                        child: const Text(
                          'Войти',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.pink,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class CampusInputField extends StatelessWidget {
  const CampusInputField({
    super.key,
    required this.hintText,
    this.obscureText = false,
    this.keyboardType,
    this.suffixIcon,
  });

  final String hintText;
  final bool obscureText;
  final TextInputType? keyboardType;
  final Widget? suffixIcon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      height: 48,
      child: TextField(
        obscureText: obscureText,
        keyboardType: keyboardType,
        style: TextStyle(fontSize: 14, color: theme.colorScheme.onSurface),
        cursorColor: AppTheme.pink,
        decoration: InputDecoration(hintText: hintText, suffixIcon: suffixIcon),
      ),
    );
  }
}

class GradientButton extends StatelessWidget {
  const GradientButton({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 210,
      height: 44,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: AppTheme.buttonGradient,
        boxShadow: const [
          BoxShadow(
            color: Color(0x40FF007A),
            blurRadius: 14,
            offset: Offset(0, 7),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: () {},
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

class GradientText extends StatelessWidget {
  const GradientText(
    this.text, {
    super.key,
    required this.gradient,
    required this.style,
  });

  final String text;
  final Gradient gradient;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (bounds) {
        return gradient.createShader(
          Rect.fromLTWH(0, 0, bounds.width, bounds.height),
        );
      },
      child: Text(text, style: style.copyWith(color: Colors.white)),
    );
  }
}

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
