import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../config.dart';
import '../models/models.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  ApiException(this.message, [this.statusCode]);

  @override
  String toString() => message;
}

/// Semua pemanggilan REST API lewat sini. Token JWT disimpan di [token].
class ApiService {
  ApiService._();
  static final ApiService instance = ApiService._();

  String? _token;
  String? get token => _token;
  set token(String? v) {
    if (v != _token) _fotoCache.clear(); // ganti akun -> buang foto yang tersimpan
    _token = v;
  }

  /// Dipanggil saat server membalas 401 padahal sudah login (token kedaluwarsa).
  void Function()? onUnauthorized;

  Future<Map<String, dynamic>> _send(
    String method,
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? query,
  }) async {
    final uri = Uri.parse('${AppConfig.baseUrl}$path').replace(queryParameters: query);
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
    final encoded = body == null ? null : jsonEncode(body);

    http.Response res;
    try {
      final Future<http.Response> req;
      switch (method) {
        case 'POST':
          req = http.post(uri, headers: headers, body: encoded);
          break;
        case 'PATCH':
          req = http.patch(uri, headers: headers, body: encoded);
          break;
        case 'DELETE':
          req = http.delete(uri, headers: headers);
          break;
        default:
          req = http.get(uri, headers: headers);
      }
      res = await req.timeout(const Duration(seconds: 15));
    } catch (_) {
      throw ApiException(
        'Tidak dapat terhubung ke server. Pastikan server berjalan dan alamatnya benar (${AppConfig.baseUrl}).',
      );
    }

    Map<String, dynamic> data = {};
    try {
      if (res.body.isNotEmpty) {
        final decoded = jsonDecode(utf8.decode(res.bodyBytes));
        if (decoded is Map<String, dynamic>) data = decoded;
      }
    } catch (_) {
      // body bukan JSON; ditangani lewat status code di bawah
    }

    if (res.statusCode >= 400) {
      if (res.statusCode == 401 && token != null) onUnauthorized?.call();
      throw ApiException(
        (data['error'] as String?) ?? 'Terjadi kesalahan (${res.statusCode})',
        res.statusCode,
      );
    }
    return data;
  }

  // ---------------------------------------------------------------- Auth
  /// [identifier]: NIM (mahasiswa), NIDN (dosen) atau email (fakultas).
  Future<({String token, AppUser user})> login(String identifier, String password, String role) async {
    final d = await _send('POST', '/api/auth/login',
        body: {'identifier': identifier, 'password': password, 'role': role});
    return (token: d['token'] as String, user: AppUser.fromJson(d['user'] as Map<String, dynamic>));
  }

  Future<AppUser> me() async {
    final d = await _send('GET', '/api/auth/me');
    return AppUser.fromJson(d['user'] as Map<String, dynamic>);
  }

  // ---------------------------------------------------- Pengaduan (user)
  /// [fotos]: foto lampiran (opsional, maks. 3) yang dikirim sebagai base64.
  Future<Complaint> createComplaint(
    String judul,
    String lokasi,
    String deskripsi, {
    List<({String nama, Uint8List bytes})> fotos = const [],
  }) async {
    final d = await _send('POST', '/api/complaints', body: {
      'judul': judul,
      'lokasi': lokasi,
      'deskripsi': deskripsi,
      if (fotos.isNotEmpty)
        'foto': fotos.map((f) => {'nama': f.nama, 'data': base64Encode(f.bytes)}).toList(),
    });
    return Complaint.fromJson(d['complaint'] as Map<String, dynamic>);
  }

  /// Beranda informasi laporan: pengaduan yang masih menunggu/diproses.
  /// Mahasiswa & dosen mendapat miliknya sendiri, fakultas mendapat semua.
  Future<List<Complaint>> activeComplaints() async {
    final d = await _send('GET', '/api/complaints/aktif');
    return (d['complaints'] as List)
        .map((e) => Complaint.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  final Map<String, Future<Uint8List>> _fotoCache = {};

  /// Mengunduh gambar lampiran (butuh token). Hasil di-cache selama aplikasi berjalan.
  Future<Uint8List> fetchFoto(String path) {
    return _fotoCache.putIfAbsent(path, () async {
      try {
        final res = await http
            .get(Uri.parse('${AppConfig.baseUrl}$path'),
                headers: {if (token != null) 'Authorization': 'Bearer $token'})
            .timeout(const Duration(seconds: 20));
        if (res.statusCode != 200) throw ApiException('Foto tidak dapat dimuat', res.statusCode);
        return res.bodyBytes;
      } catch (e) {
        _fotoCache.remove(path);
        if (e is ApiException) rethrow;
        throw ApiException('Foto tidak dapat dimuat');
      }
    });
  }

  Future<List<Complaint>> myComplaints() async {
    final d = await _send('GET', '/api/complaints/mine');
    return (d['complaints'] as List)
        .map((e) => Complaint.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<TrackResult> track(String kode) async {
    final d = await _send('GET', '/api/complaints/track/${Uri.encodeComponent(kode.trim())}');
    return TrackResult(
      Complaint.fromJson(d['complaint'] as Map<String, dynamic>),
      (d['riwayat'] as List).map((e) => TrackLog.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }

  // ------------------------------------------------------------ Fakultas
  Future<List<Complaint>> allComplaints({String status = 'semua'}) async {
    final d = await _send('GET', '/api/complaints', query: {'status': status});
    return (d['complaints'] as List)
        .map((e) => Complaint.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Complaint> updateStatus(int id, String status, String catatan) async {
    final d = await _send('PATCH', '/api/complaints/$id/status',
        body: {'status': status, 'catatan': catatan});
    return Complaint.fromJson(d['complaint'] as Map<String, dynamic>);
  }

  Future<Dashboard> dashboard() async {
    final d = await _send('GET', '/api/dashboard');
    return Dashboard.fromJson(d);
  }

  Future<List<ReviewItem>> surveys() async {
    final d = await _send('GET', '/api/surveys');
    return (d['surveys'] as List)
        .map((e) => ReviewItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // -------------------------------------------------------------- Survei
  Future<void> submitSurvey(int complaintId, String rating, String? keterangan) async {
    await _send('POST', '/api/surveys', body: {
      'complaint_id': complaintId,
      'rating': rating,
      if (keterangan != null && keterangan.trim().isNotEmpty) 'keterangan': keterangan.trim(),
    });
  }

  Future<SurveyStats> surveyStats() async {
    final d = await _send('GET', '/api/surveys/stats');
    return SurveyStats.fromJson(d);
  }

  // ------------------------------------------- Kelola akun (khusus Fakultas)
  Future<List<AppUser>> listUsers() async {
    final d = await _send('GET', '/api/users');
    return (d['users'] as List).map((e) => AppUser.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Mengembalikan akun baru + sandi awal (dibuat otomatis jika [password] kosong).
  Future<({AppUser user, String password})> createUser({
    required String role,
    required String nama,
    required String nomorInduk,
    required String email,
    required String alamat,
    String? password,
  }) async {
    final d = await _send('POST', '/api/users', body: {
      'role': role,
      'nama': nama,
      'nomor_induk': nomorInduk,
      'email': email,
      'alamat': alamat,
      if (password != null && password.isNotEmpty) 'password': password,
    });
    return (user: AppUser.fromJson(d['user'] as Map<String, dynamic>), password: d['password_awal'] as String);
  }

  Future<AppUser> updateUser(
    int id, {
    required String nama,
    required String nomorInduk,
    required String email,
    required String alamat,
  }) async {
    final d = await _send('PATCH', '/api/users/$id', body: {
      'nama': nama,
      'nomor_induk': nomorInduk,
      'email': email,
      'alamat': alamat,
    });
    return AppUser.fromJson(d['user'] as Map<String, dynamic>);
  }

  /// Lupa sandi: atur ulang. Jika [password] kosong, server membuat sandi sementara.
  Future<String> resetPassword(int id, {String? password}) async {
    final d = await _send('POST', '/api/users/$id/reset-password',
        body: {if (password != null && password.isNotEmpty) 'password': password});
    return d['password_baru'] as String;
  }

  Future<void> deleteUser(int id) async {
    await _send('DELETE', '/api/users/$id');
  }
}
