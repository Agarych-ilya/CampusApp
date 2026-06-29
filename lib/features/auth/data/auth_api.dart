import 'dart:convert';

import 'package:http/http.dart' as http;

class AuthApi {
  static const String _baseUrl = 'http://10.0.2.2:8000';

  Future<String> register({
    required String username,
    required String email,
    required String password,
  }) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'username': username,
        'email': email,
        'password': password,
      }),
    );

    final Map<String, dynamic> data = jsonDecode(response.body);

    if (response.statusCode == 201) {
      return data['message'];
    }

    throw Exception(data['detail'] ?? 'Ошибка регистрации');
  }

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );

    final Map<String, dynamic> data = jsonDecode(response.body);

    if (response.statusCode == 200) {
      return data;
    }

    throw Exception(data['detail'] ?? 'Ошибка входа');
  }
}
