import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';
import '../services/api_service.dart';


class AuthProvider extends ChangeNotifier {
  /// [role] menentukan "slot" sesi tersimpan. Mahasiswa, Dosen, dan Fakultas masing-masing
  /// punya token sendiri, jadi bisa login bersamaan di tab berbeda tanpa saling menimpa.
  AuthProvider(this.role) {
    ApiService.instance.onUnauthorized = _forceLogout;
  }

  final String role;
  String get _tokenKey => 'auth_token_$role';

  AppUser? user;
  bool initializing = true;

  final ApiService _api = ApiService.instance;

  /// Dipanggil saat aplikasi dibuka: pulihkan sesi dari token tersimpan.
  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_tokenKey);
      if (saved != null) {
        _api.token = saved;
        final u = await _api.me();
        if (u.role != role) {
          // Token ini bukan milik halaman peran ini -> abaikan.
          throw StateError('peran tidak cocok');
        }
        user = u;
      }
    } catch (_) {
      _api.token = null;
      user = null;
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_tokenKey);
    }
    initializing = false;
    notifyListeners();
  }

  /// [identifier]: NIM (mahasiswa), NIDN (dosen) atau email (fakultas).
  Future<void> login(String identifier, String password, String role) async {
    final r = await _api.login(identifier.trim(), password, this.role);
    await _save(r.token, r.user);
  }

  Future<void> _save(String token, AppUser u) async {
    _api.token = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
    user = u;
    notifyListeners();
  }

  Future<void> logout() async {
    _api.token = null;
    user = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    notifyListeners();
  }

  void _forceLogout() {
    logout();
  }
}
