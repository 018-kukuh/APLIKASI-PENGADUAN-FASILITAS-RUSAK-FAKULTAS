import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/models.dart';
import '../../services/api_service.dart';
import '../../theme.dart';
import '../../widgets/common.dart';

/// Fitur 5 (Fakultas): kelola akun mahasiswa & dosen.
/// - Lihat data (nama, NIM/NIDN, gmail, alamat), cari
/// - Tambah akun baru, perbarui data akun
/// - Reset sandi (jika mahasiswa/dosen lupa sandi)
class AccountsScreen extends StatefulWidget {
  const AccountsScreen({super.key});

  @override
  State<AccountsScreen> createState() => _AccountsScreenState();
}

class _AccountsScreenState extends State<AccountsScreen> {
  String _role = 'mahasiswa';
  final _search = TextEditingController();
  List<AppUser> _all = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await ApiService.instance.listUsers();
      if (!mounted) return;
      setState(() {
        _all = list;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  List<AppUser> get _visible {
    final q = _search.text.trim().toLowerCase();
    return _all.where((u) {
      if (u.role != _role) return false;
      if (q.isEmpty) return true;
      return [u.nama, u.nomorInduk, u.email, u.alamat]
          .any((v) => (v ?? '').toLowerCase().contains(q));
    }).toList();
  }

  String get _idLabel => _role == 'mahasiswa' ? 'NIM' : 'NIDN';

  Future<void> _tambah() async {
    final hasil = await showDialog<({AppUser user, String password})>(
      context: context,
      builder: (_) => _UserFormDialog(role: _role),
    );
    if (hasil == null || !mounted) return;
    await _load();
    if (!mounted) return;
    await _showCredential(
      title: 'Akun berhasil dibuat',
      idLabel: _idLabelFor(hasil.user.role),
      user: hasil.user,
      password: hasil.password,
      catatan: 'Berikan NIM/NIDN dan sandi awal ini kepada yang bersangkutan.',
    );
  }

  Future<void> _edit(AppUser u) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => _UserFormDialog(role: u.role, existing: u),
    );
    if (ok == true && mounted) {
      showSnack(context, 'Data akun diperbarui');
      _load();
    }
  }

  Future<void> _resetSandi(AppUser u) async {
    final baru = await showDialog<String>(
      context: context,
      builder: (_) => _ResetPasswordDialog(user: u),
    );
    if (baru == null || !mounted) return;
    await _showCredential(
      title: 'Sandi berhasil direset',
      idLabel: _idLabelFor(u.role),
      user: u,
      password: baru,
      catatan: 'Berikan sandi baru ini kepada yang bersangkutan. '
          'Sesi login lama otomatis berakhir.',
    );
  }

  Future<void> _hapus(AppUser u) async {
    final ya = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus akun'),
        content: Text('Hapus akun ${u.nama}? Tindakan ini tidak bisa dibatalkan.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          FilledButton(
            style: FilledButton.styleFrom(
              minimumSize: const Size(80, 40),
              backgroundColor: const Color(0xFFDC2626),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (ya != true || !mounted) return;
    try {
      await ApiService.instance.deleteUser(u.id);
      if (!mounted) return;
      showSnack(context, 'Akun ${u.nama} dihapus');
      _load();
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message);
    }
  }

  String _idLabelFor(String role) => role == 'mahasiswa' ? 'NIM' : 'NIDN';

  Future<void> _showCredential({
    required String title,
    required String idLabel,
    required AppUser user,
    required String password,
    required String catatan,
  }) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(user.nama, style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            Text('$idLabel: ${user.nomorInduk ?? '-'}'),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: SelectableText(
                    'Sandi: $password',
                    style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.w700),
                  ),
                ),
                IconButton(
                  tooltip: 'Salin sandi',
                  icon: const Icon(Icons.copy, size: 20),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: password));
                    showSnack(ctx, 'Sandi disalin');
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(catatan, style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
          ],
        ),
        actions: [
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(80, 40)),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Selesai'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final list = _visible;
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _loading ? null : _tambah,
        icon: const Icon(Icons.person_add_alt_1),
        label: Text('Tambah ${roleLabel(_role)}'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'mahasiswa', label: Text('Mahasiswa'), icon: Icon(Icons.school_outlined)),
                ButtonSegment(value: 'dosen', label: Text('Dosen'), icon: Icon(Icons.person_outline)),
              ],
              selected: {_role},
              onSelectionChanged: (s) => setState(() => _role = s.first),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _search,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Cari nama, $_idLabel, gmail, atau alamat',
                prefixIcon: const Icon(Icons.search),
                isDense: true,
                suffixIcon: _search.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => setState(_search.clear),
                      ),
              ),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? ErrorState(message: _error!, onRetry: _load)
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: list.isEmpty
                            ? ListView(
                                physics: const AlwaysScrollableScrollPhysics(),
                                children: const [
                                  SizedBox(height: 80),
                                  EmptyState('Tidak ada akun yang cocok.', icon: Icons.search_off),
                                ],
                              )
                            : ListView.builder(
                                physics: const AlwaysScrollableScrollPhysics(),
                                padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                                itemCount: list.length,
                                itemBuilder: (_, i) => _UserCard(
                                  user: list[i],
                                  idLabel: _idLabel,
                                  onEdit: () => _edit(list[i]),
                                  onReset: () => _resetSandi(list[i]),
                                  onDelete: () => _hapus(list[i]),
                                ),
                              ),
                      ),
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------ Kartu
class _UserCard extends StatelessWidget {
  final AppUser user;
  final String idLabel;
  final VoidCallback onEdit;
  final VoidCallback onReset;
  final VoidCallback onDelete;
  const _UserCard({
    required this.user,
    required this.idLabel,
    required this.onEdit,
    required this.onReset,
    required this.onDelete,
  });

  Widget _line(IconData icon, String text) => Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 16, color: Colors.grey.shade600),
            const SizedBox(width: 6),
            Expanded(child: Text(text, style: TextStyle(color: Colors.grey.shade800))),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final inisial = user.nama.isEmpty ? '?' : user.nama.trim()[0].toUpperCase();
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1.5,
      shadowColor: Colors.black26,
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 8, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: kNavy,
                  child: Text(inisial, style: const TextStyle(fontWeight: FontWeight.w700, color: kGold)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(user.nama,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            _line(Icons.badge_outlined, '$idLabel: ${user.nomorInduk ?? '-'}'),
            _line(Icons.mail_outline, user.email),
            _line(Icons.home_outlined, (user.alamat ?? '').isEmpty ? '-' : user.alamat!),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Ubah data'),
                ),
                TextButton.icon(
                  onPressed: onReset,
                  icon: const Icon(Icons.lock_reset, size: 18),
                  label: const Text('Reset sandi'),
                ),
                TextButton.icon(
                  style: TextButton.styleFrom(foregroundColor: const Color(0xFFDC2626)),
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text('Hapus'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------------- Dialog tambah/ubah
class _UserFormDialog extends StatefulWidget {
  final String role;
  final AppUser? existing;
  const _UserFormDialog({required this.role, this.existing});

  @override
  State<_UserFormDialog> createState() => _UserFormDialogState();
}

class _UserFormDialogState extends State<_UserFormDialog> {
  final _form = GlobalKey<FormState>();
  late final _nama = TextEditingController(text: widget.existing?.nama ?? '');
  late final _induk = TextEditingController(text: widget.existing?.nomorInduk ?? '');
  late final _email = TextEditingController(text: widget.existing?.email ?? '');
  late final _alamat = TextEditingController(text: widget.existing?.alamat ?? '');
  final _pass = TextEditingController();
  bool _saving = false;
  String? _error;

  bool get _isEdit => widget.existing != null;
  bool get _isMhs => widget.role == 'mahasiswa';
  String get _idLabel => _isMhs ? 'NIM' : 'NIDN';

  @override
  void dispose() {
    _nama.dispose();
    _induk.dispose();
    _email.dispose();
    _alamat.dispose();
    _pass.dispose();
    super.dispose();
  }

  Future<void> _simpan() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final api = ApiService.instance;
      if (_isEdit) {
        await api.updateUser(
          widget.existing!.id,
          nama: _nama.text.trim(),
          nomorInduk: _induk.text.trim(),
          email: _email.text.trim(),
          alamat: _alamat.text.trim(),
        );
        if (mounted) Navigator.pop(context, true);
      } else {
        final r = await api.createUser(
          role: widget.role,
          nama: _nama.text.trim(),
          nomorInduk: _induk.text.trim(),
          email: _email.text.trim(),
          alamat: _alamat.text.trim(),
          password: _pass.text,
        );
        if (mounted) Navigator.pop(context, r);
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = e.message;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEdit ? 'Ubah data ${roleLabel(widget.role)}' : 'Tambah ${roleLabel(widget.role)}'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Form(
            key: _form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 4),
                TextFormField(
                  controller: _nama,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Nama lengkap',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  validator: (v) => (v ?? '').trim().isEmpty ? 'Nama wajib diisi' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _induk,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    labelText: _isMhs ? 'NIM' : 'NIDN (10 digit)',
                    helperText: 'Dipakai untuk login',
                    prefixIcon: const Icon(Icons.badge_outlined),
                  ),
                  validator: (v) {
                    final t = (v ?? '').trim();
                    if (t.isEmpty) return '$_idLabel wajib diisi';
                    if (_isMhs && (t.length < 5 || t.length > 20)) return 'NIM 5-20 digit angka';
                    if (!_isMhs && t.length != 10) return 'NIDN harus 10 digit angka';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Gmail / email',
                    prefixIcon: Icon(Icons.mail_outline),
                  ),
                  validator: (v) {
                    final t = (v ?? '').trim();
                    if (t.isEmpty) return 'Email wajib diisi';
                    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(t)) {
                      return 'Format email tidak valid';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _alamat,
                  maxLines: 2,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Alamat',
                    prefixIcon: Icon(Icons.home_outlined),
                  ),
                  validator: (v) => (v ?? '').trim().isEmpty ? 'Alamat wajib diisi' : null,
                ),
                if (!_isEdit) ...[
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _pass,
                    decoration: const InputDecoration(
                      labelText: 'Sandi awal (opsional)',
                      helperText: 'Kosongkan untuk dibuat otomatis',
                      prefixIcon: Icon(Icons.lock_outline),
                    ),
                    validator: (v) =>
                        (v ?? '').isNotEmpty && v!.length < 6 ? 'Minimal 6 karakter' : null,
                  ),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: const TextStyle(color: Color(0xFFDC2626))),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(90, 40)),
          onPressed: _saving ? null : _simpan,
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('Simpan'),
        ),
      ],
    );
  }
}

// ------------------------------------------------------- Dialog reset sandi
class _ResetPasswordDialog extends StatefulWidget {
  final AppUser user;
  const _ResetPasswordDialog({required this.user});

  @override
  State<_ResetPasswordDialog> createState() => _ResetPasswordDialogState();
}

class _ResetPasswordDialogState extends State<_ResetPasswordDialog> {
  final _form = GlobalKey<FormState>();
  final _pass = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _pass.dispose();
    super.dispose();
  }

  Future<void> _reset() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final baru = await ApiService.instance.resetPassword(widget.user.id, password: _pass.text);
      if (mounted) Navigator.pop(context, baru);
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = e.message;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Reset sandi'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Atur ulang sandi untuk ${widget.user.nama}.'),
              const SizedBox(height: 12),
              TextFormField(
                controller: _pass,
                decoration: const InputDecoration(
                  labelText: 'Sandi baru (opsional)',
                  helperText: 'Kosongkan untuk dibuat otomatis',
                  prefixIcon: Icon(Icons.lock_outline),
                ),
                validator: (v) =>
                    (v ?? '').isNotEmpty && v!.length < 6 ? 'Minimal 6 karakter' : null,
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: Color(0xFFDC2626))),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(90, 40)),
          onPressed: _saving ? null : _reset,
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('Reset'),
        ),
      ],
    );
  }
}
