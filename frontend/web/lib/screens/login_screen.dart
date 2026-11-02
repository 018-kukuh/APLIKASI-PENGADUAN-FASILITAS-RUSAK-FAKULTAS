import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Halaman login khusus satu peran ('mahasiswa' | 'dosen' | 'fakultas').
/// Tidak ada pemilih peran dan tidak ada tautan antar peran: tiap peran punya tautan sendiri.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.role});

  final String role;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _id = TextEditingController();
  final _pass = TextEditingController();
  String get _role => widget.role;
  bool _obscure = true;
  bool _loading = false;

  @override
  void dispose() {
    _id.dispose();
    _pass.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    final auth = context.read<AuthProvider>();
    setState(() => _loading = true);
    try {
      await auth.login(_id.text, _pass.text, _role);
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // Mahasiswa login dengan NIM, dosen dengan NIDN, fakultas dengan email.
  String get _idLabel => _role == 'mahasiswa' ? 'NIM' : (_role == 'dosen' ? 'NIDN' : 'Email');

  String get _judul => switch (_role) {
        'dosen' => 'Masuk Dosen',
        'fakultas' => 'Masuk Fakultas',
        _ => 'Masuk Mahasiswa',
      };

  String get _subjudul => switch (_role) {
        'dosen' => 'Masukkan NIDN dan kata sandi Anda.',
        'fakultas' => 'Khusus pengelola Fakultas. Masukkan email dan kata sandi.',
        _ => 'Masukkan NIM dan kata sandi Anda.',
      };

  IconData get _idIcon => _role == 'fakultas' ? Icons.mail_outline : Icons.badge_outlined;

  // Matriks hitam-putih (saturasi 0) supaya foto tidak mengubah rona biru.
  static const List<double> _grayscale = <double>[
    0.2126, 0.7152, 0.0722, 0, 0,
    0.2126, 0.7152, 0.0722, 0, 0,
    0.2126, 0.7152, 0.0722, 0, 0,
    0, 0, 0, 1, 0,
  ];

  Widget _hero(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [kNavy, kNavyLight],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(36)),
      ),
      child: Stack(
        fit: StackFit.passthrough, // Column tetap selebar penuh (konten tetap di tengah)
        children: [
          // Foto gedung: hitam-putih, sangat transparan (tekstur), fokus digeser ke bawah/samping
          // supaya tulisan "FAKULTAS TEKNIK" di gedung tidak jatuh di belakang judul.
          Positioned.fill(
            child: Opacity(
              opacity: 0.07,
              child: ColorFiltered(
                colorFilter: const ColorFilter.matrix(_grayscale),
                child: Image.asset(
                  'assets/images/fakultas.jpg',
                  fit: BoxFit.cover,
                  alignment: const Alignment(0.6, 1.0),
                ),
              ),
            ),
          ),
          // Overlay biru: paling pekat (0.92) di tengah tempat judul berada.
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [kNavy.withAlpha(90), kNavy.withAlpha(235), kNavy.withAlpha(235), kNavy.withAlpha(90)],
                  stops: const [0.0, 0.35, 0.65, 1.0],
                ),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(24, top + 36, 24, 84),
            child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: Colors.black.withAlpha(60), blurRadius: 20, offset: const Offset(0, 8)),
                ],
              ),
              child: const LogoMark(size: 88),
            ),
            const SizedBox(height: 20),
            const Text(
              'Pengaduan Fasilitas',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            const Text(
              'Fakultas Teknik · Universitas Madura',
              textAlign: TextAlign.center,
              style: TextStyle(color: kGold, fontSize: 14, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
            Text(
              'Laporkan fasilitas kampus yang rusak dan pantau proses penanganannya.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white.withAlpha(200), fontSize: 13.5),
            ),
          ],
        ),
          ),
        ],
      ),
    );
  }

  Widget _formCard() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: kNavy.withAlpha(30), blurRadius: 28, offset: const Offset(0, 10)),
        ],
      ),
      child: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_judul, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(_subjudul, style: TextStyle(fontSize: 13, color: Colors.blueGrey.shade600)),
            const SizedBox(height: 18),
            TextFormField(
              controller: _id,
              keyboardType: _role == 'fakultas' ? TextInputType.emailAddress : TextInputType.number,
              inputFormatters: _role == 'fakultas' ? null : [FilteringTextInputFormatter.digitsOnly],
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: _idLabel,
                hintText: _role == 'fakultas' ? 'contoh: admin@fakultas.ac.id' : null,
                prefixIcon: Icon(_idIcon),
              ),
              validator: (v) {
                final t = (v ?? '').trim();
                if (t.isEmpty) return '$_idLabel wajib diisi';
                if (_role == 'fakultas' && !t.contains('@')) return 'Format email tidak valid';
                return null;
              },
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _pass,
              obscureText: _obscure,
              onFieldSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                labelText: 'Kata sandi',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
              validator: (v) => (v ?? '').isEmpty ? 'Kata sandi wajib diisi' : null,
            ),
            const SizedBox(height: 22),
            FilledButton(
              onPressed: _loading ? null : _submit,
              child: _loading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                    )
                  : const Text('Masuk', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            ),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, size: 16, color: Colors.blueGrey.shade500),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _role == 'fakultas'
                        ? 'Gunakan email dan kata sandi akun Fakultas.'
                        : 'Lupa kata sandi atau data akun salah? Hubungi pihak Fakultas '
                            'untuk mengatur ulang / memperbarui akun Anda.',
                    style: TextStyle(fontSize: 12.5, color: Colors.blueGrey.shade600),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          children: [
            _hero(context),
            Transform.translate(
              offset: const Offset(0, -48),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: _formCard(),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Text(
                '© Fakultas Teknik · Universitas Madura',
                style: TextStyle(fontSize: 12, color: Colors.blueGrey.shade500),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
