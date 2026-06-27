import 'package:flutter/material.dart';
import '../widgets/widgets.dart';
import '/core/theme/app_theme.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  bool _passwordHidden = true;
  bool _repeatPasswordHidden = true;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context); //Получаем текущую тему приложения
    final textColor = theme.colorScheme.onSurface; //Получаем текущий цвет текса из темы
    final secondaryTextColor = theme.colorScheme.onSurfaceVariant; //Второстеппенный цвет текста из темы

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(28, 0, 28, 18),
            child: Transform.translate(
              offset: const Offset(0, -35), // Здесь регулируется высота всего блока.
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 360),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const GradientText(
                      'CAMPUS',
                      style: TextStyle(
                        fontSize: 50,
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
                          onTap: () {
                            // Здесь потом будет переход на экран входа.
                          },
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
      ),
    );
  }
}





