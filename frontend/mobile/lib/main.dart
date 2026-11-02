import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'providers/auth_provider.dart';
import 'screens/fakultas/fakultas_home.dart';
import 'screens/login_screen.dart';
import 'screens/user/user_home.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('id_ID');
  runApp(
    ChangeNotifierProvider(
      create: (_) => AuthProvider(_roleAwal())..init(),
      child: const MyApp(),
    ),
  );
}

/// Tiga tautan login terpisah (web):
///   .../#/mahasiswa   -> login Mahasiswa (juga tampilan bawaan bila tanpa tautan khusus)
///   .../#/dosen       -> login Dosen
///   .../#/fakultas    -> login Fakultas
/// Tidak ada tautan antar halaman; tiap peran hanya bisa dibuka dari tautannya sendiri.
/// Catatan: setelah mengganti bagian `#/...` di alamat, muat ulang halaman (F5).
String _roleAwal() {
  final alamat = '${Uri.base.fragment} ${Uri.base.path}'.toLowerCase();
  if (alamat.contains('fakultas')) return 'fakultas';
  if (alamat.contains('dosen')) return 'dosen';
  return 'mahasiswa';
}

class LoginGate extends StatelessWidget {
  const LoginGate({super.key});

  @override
  Widget build(BuildContext context) => LoginScreen(role: _roleAwal());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pengaduan Fasilitas Fakultas Teknik',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: Consumer<AuthProvider>(
        builder: (context, auth, _) {
          if (auth.initializing) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }
          final u = auth.user;
          if (u == null) return const LoginGate();
          if (u.role == 'fakultas') return const FakultasHome();
          return const UserHome();
        },
      ),
    );
  }
}
