import 'package:flutter/material.dart';

import '../widgets/widgets.dart';
import '/core/theme/app_theme.dart';
import '../data/auth_api.dart';
import 'login_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final AuthApi _authApi = AuthApi();

  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _repeatPasswordController =
      TextEditingController();

  bool _passwordHidden = true;
  bool _repeatPasswordHidden = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _repeatPasswordController.dispose();

    super.dispose();
  }

  Future<void> _register() async {
    FocusScope.of(context).unfocus();

    final username = _usernameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final repeatPassword = _repeatPasswordController.text;

    if (username.isEmpty ||
        email.isEmpty ||
        password.isEmpty ||
        repeatPassword.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Заполните все поля'),
        ),
      );
      return;
    }

    if (password != repeatPassword) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Пароли не совпадают'),
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final message = await _authApi.register(
        username: username,
        email: email,
        password: password,
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error.toString().replaceFirst('Exception: ', ''),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

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
            padding: const EdgeInsets.fromLTRB(28, 0, 28, 18),
            child: Transform.translate(
              offset: const Offset(0, -35),
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

                    CampusInputField(
                      controller: _usernameController,
                      hintText: 'name surname',
                      keyboardType: TextInputType.name,
                    ),

                    const SizedBox(height: 14),

                    CampusInputField(
                      controller: _emailController,
                      hintText: 'student@mpei.ru',
                      keyboardType: TextInputType.emailAddress,
                    ),

                    const SizedBox(height: 14),

                    CampusInputField(
                      controller: _passwordController,
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
                      controller: _repeatPasswordController,
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

                    GradientButton(
                      text : 'Зарегистрироваться',
                      isLoading: _isLoading,
                      onPressed : _register,
                    ),

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
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => const LoginScreen(),
                              ),
                            );
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


