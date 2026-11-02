import 'package:flutter/foundation.dart';

/// Alamat server API (tanpa "/api"; path lengkap ditambahkan di ApiService).
///
/// Otomatis dipilih sesuai platform:
///  - Flutter Web / Windows / macOS / iOS Simulator : http://localhost:3000
///  - Android Emulator                              : http://10.0.2.2:3000
///
/// HP fisik: jalankan dengan IP laptop Anda (satu Wi-Fi), contoh:
///   flutter run --dart-define=API_URL=http://192.168.1.10:3000
class AppConfig {
  AppConfig._();

  static const String _dariEnv = String.fromEnvironment('API_URL');

  static String get baseUrl {
    if (_dariEnv.isNotEmpty) return _dariEnv;
    if (kIsWeb) return 'http://localhost:3000';
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:3000';
    }
    return 'http://localhost:3000';
  }
}
