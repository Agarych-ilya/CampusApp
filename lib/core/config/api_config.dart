class ApiConfig {
  ApiConfig._();

  // Local development backend on the same Wi-Fi network as a real phone.
  // Override for your own PC/network:
  // flutter run --dart-define=CAMPUS_API_BASE_URL=http://192.168.x.x:8000
  static const String host = '192.168.1.5';
  static const int port = 8000;

  static const String baseUrl = String.fromEnvironment(
    'CAMPUS_API_BASE_URL',
    defaultValue: 'http://192.168.1.5:8000',
  );

  // Special address of the host PC from the Android Studio emulator.
  static const String emulatorBaseUrl = 'http://10.0.2.2:8000';

  /// The schedule API can probe the Android emulator host as a fallback.
  /// Other app features continue using [baseUrl] unchanged.
  static List<String> get scheduleBaseUrls {
    final configured = baseUrl.replaceAll(RegExp(r'/$'), '');
    if (configured == emulatorBaseUrl ||
        const String.fromEnvironment('CAMPUS_API_BASE_URL').isNotEmpty) {
      return [configured];
    }
    return [configured, emulatorBaseUrl];
  }
}
