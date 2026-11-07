class ApiConfig {
  ApiConfig._();

  // Address of the local backend for physical Android devices on your Wi-Fi.
  static const String host = '192.168.1.5';
  static const int port = 8000;

  // Override from the Flutter launch command:
  // flutter run -d emulator-5554 --dart-define=CAMPUS_API_BASE_URL=http://10.0.2.2:8000
  // flutter run -d <phone_id> --dart-define=CAMPUS_API_BASE_URL=http://192.168.x.x:8000
  static const String configuredBaseUrl =
      String.fromEnvironment('CAMPUS_API_BASE_URL');

  static const String baseUrl = configuredBaseUrl == ''
      ? 'http://192.168.1.5:8000'
      : configuredBaseUrl;

  // This reserved address points from the emulator to the host PC.
  static const String emulatorBaseUrl = 'http://10.0.2.2:8000';

  /// On default settings, schedule tries the LAN address and then the
  /// emulator bridge. Explicit overrides never fall back to another server.
  static List<String> get scheduleBaseUrls {
    final configured = baseUrl.replaceAll(RegExp(r'/$'), '');

    if (configuredBaseUrl.isNotEmpty || configured == emulatorBaseUrl) {
      return [configured];
    }

    return [configured, emulatorBaseUrl];
  }
}
