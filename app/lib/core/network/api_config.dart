import 'package:flutter/foundation.dart';

class ApiConfig {
  static const String _baseUrlAmbiente = String.fromEnvironment('API_BASE_URL');

  static String get baseUrl {
    if (_baseUrlAmbiente.isNotEmpty) return _baseUrlAmbiente;
    if (defaultTargetPlatform == TargetPlatform.android) {
      // Emulador Android: o host da máquina é 10.0.2.2.
      return 'http://10.0.2.2:3000/api/v1';
    }
    return 'http://localhost:3000/api/v1';
  }

  static const Duration requestTimeout = Duration(seconds: 15);
  static const String mockAsset = 'assets/mock/api_responses.json';
}
