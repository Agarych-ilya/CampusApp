import 'package:flutter/material.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();

}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 30),
            // Поле для email
            TextField(
              controller: _emailController,
              decoration: InputDecoration(
                hintText: 'hello@example.com',
                labelText: 'Студенческий email',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.emailAddress,
            ),

            const SizedBox(height: 20),

            // Текст про @gympel.ru
            const Text(
              'Чтобы войти в приложение, необходимо использовать\nстуденческую почту, оканчивающуюся на @gympel.ru',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),

            const SizedBox(height: 30),

            // Кнопка входа
            ElevatedButton(
              onPressed: () {
                final email = _emailController.text;
                if (email.endsWith('@gympel.ru')) {
                  // Переход на главный экран
                  Navigator.pushReplacementNamed(context, '/login');
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Используйте email @gympel.ru')),
                  );
                }
              },
              child: const Text('Войти'),
            ),
          ],
        ),
      ),
    );
  }
}
