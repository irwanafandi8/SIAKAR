class AppConfig {
  /// Default base URL mengarah ke emulator Android (10.0.2.2).
  /// Ubah ke IP komputer fisik (mis. 192.168.1.x) bila menguji di HP fisik via Wi-Fi.
  static String baseUrl = const String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8000/api/v1',
  );

  static const int connectTimeoutMs = 10000;
  static const int receiveTimeoutMs = 15000;

  static const String tokenKey = 'siakar_auth_token';
  static const String deviceIdKey = 'siakar_device_id';
}
