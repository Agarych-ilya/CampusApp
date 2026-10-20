class ApiConfig {
  ApiConfig._();

  // Меняешь IP ТОЛЬКО ЗДЕСЬ.
  static const String host = '192.168.1.5';

  static const int port = 8000;

  static const String baseUrl = 'http://$host:$port';
}
