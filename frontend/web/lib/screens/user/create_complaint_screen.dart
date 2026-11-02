import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/models.dart';
import '../../services/api_service.dart';
import '../../widgets/common.dart';

/// Fitur 1: membuat pengaduan. Setelah terkirim, pelapor mendapat kode unik.
class CreateComplaintScreen extends StatefulWidget {
  final VoidCallback onGoToHistory;
  const CreateComplaintScreen({super.key, required this.onGoToHistory});

  @override
  State<CreateComplaintScreen> createState() => _CreateComplaintScreenState();
}

class _CreateComplaintScreenState extends State<CreateComplaintScreen> {
  final _form = GlobalKey<FormState>();
  final _judul = TextEditingController();
  final _lokasi = TextEditingController();
  final _deskripsi = TextEditingController();
  bool _loading = false;

  // Foto lampiran (opsional, maks. 3 foto, masing-masing maks. 5 MB).
  static const _maxFoto = 3;
  static const _maxBytes = 5 * 1024 * 1024;
  final _picker = ImagePicker();
  final List<({String nama, Uint8List bytes})> _fotos = [];

  bool get _bisaKamera =>
      !kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);

  Future<void> _tambahFoto(ImageSource source) async {
    final sisa = _maxFoto - _fotos.length;
    if (sisa <= 0) {
      showSnack(context, 'Maksimal $_maxFoto foto');
      return;
    }
    try {
      final List<XFile> picked;
      if (source == ImageSource.camera || sisa == 1) {
        // pickMultiImage(limit:) mewajibkan limit >= 2, jadi sisa 1 foto lewat pickImage.
        final f = await _picker.pickImage(source: source, maxWidth: 1600, imageQuality: 80);
        picked = f == null ? [] : [f];
      } else {
        picked = await _picker.pickMultiImage(maxWidth: 1600, imageQuality: 80, limit: sisa);
      }
      for (final f in picked.take(sisa)) {
        final bytes = await f.readAsBytes();
        if (!mounted) return;
        if (bytes.length > _maxBytes) {
          showSnack(context, 'Foto "${f.name}" lebih dari 5 MB');
          continue;
        }
        setState(() => _fotos.add((nama: f.name, bytes: bytes)));
      }
    } catch (_) {
      if (mounted) showSnack(context, 'Tidak dapat mengambil foto');
    }
  }

  Widget _fotoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Foto kerusakan (opsional, maks. $_maxFoto)',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var i = 0; i < _fotos.length; i++)
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.memory(_fotos[i].bytes, width: 96, height: 96, fit: BoxFit.cover),
                  ),
                  Positioned(
                    top: 2,
                    right: 2,
                    child: InkWell(
                      onTap: _loading ? null : () => setState(() => _fotos.removeAt(i)),
                      child: const CircleAvatar(
                        radius: 12,
                        backgroundColor: Colors.black54,
                        child: Icon(Icons.close, size: 16, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
        if (_fotos.isNotEmpty) const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: _loading || _fotos.length >= _maxFoto ? null : () => _tambahFoto(ImageSource.gallery),
              icon: const Icon(Icons.photo_library_outlined),
              label: const Text('Pilih dari galeri / file'),
            ),
            if (_bisaKamera)
              OutlinedButton.icon(
                onPressed: _loading || _fotos.length >= _maxFoto ? null : () => _tambahFoto(ImageSource.camera),
                icon: const Icon(Icons.photo_camera_outlined),
                label: const Text('Kamera'),
              ),
          ],
        ),
      ],
    );
  }

  @override
  void dispose() {
    _judul.dispose();
    _lokasi.dispose();
    _deskripsi.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final c = await ApiService.instance.createComplaint(
        _judul.text.trim(),
        _lokasi.text.trim(),
        _deskripsi.text.trim(),
        fotos: List.of(_fotos),
      );
      if (!mounted) return;
      _judul.clear();
      _lokasi.clear();
      _deskripsi.clear();
      setState(() {
        _fotos.clear();
        _loading = false;
      });
      await _showKodeDialog(c);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      showSnack(context, e.message);
    }
  }

  Future<void> _showKodeDialog(Complaint c) async {
    final goHistory = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.check_circle, color: Color(0xFF16A34A), size: 48),
        title: const Text('Pengaduan terkirim'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Simpan kode unik ini untuk melacak status pengaduan Anda:'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFDBEAFE),
                borderRadius: BorderRadius.circular(10),
              ),
              child: SelectableText(
                c.kode,
                style: const TextStyle(
                    fontFamily: 'monospace', fontSize: 20, fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: c.kode));
                showSnack(ctx, 'Kode disalin');
              },
              icon: const Icon(Icons.copy, size: 18),
              label: const Text('Salin kode'),
            ),
            const SizedBox(height: 4),
            Text(
              'Batas penanganan: ${fmtDate(c.batasWaktu)} (1 hari).',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Tutup')),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(100, 40)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Lihat riwayat'),
          ),
        ],
      ),
    );
    if (goHistory == true) widget.onGoToHistory();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFDBEAFE),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Setiap pengaduan mendapat kode unik untuk pelacakan. Batas maksimal penanganan adalah 1 hari.',
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _judul,
              maxLength: 120,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Judul pengaduan',
                hintText: 'contoh: AC ruang kelas tidak dingin',
                prefixIcon: Icon(Icons.title),
              ),
              validator: (v) => (v ?? '').trim().isEmpty ? 'Judul wajib diisi' : null,
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _lokasi,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Lokasi fasilitas',
                hintText: 'contoh: Gedung A, Ruang 201',
                prefixIcon: Icon(Icons.place_outlined),
              ),
              validator: (v) => (v ?? '').trim().isEmpty ? 'Lokasi wajib diisi' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _deskripsi,
              minLines: 4,
              maxLines: 8,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Deskripsi kerusakan',
                alignLabelWithHint: true,
              ),
              validator: (v) => (v ?? '').trim().isEmpty ? 'Deskripsi wajib diisi' : null,
            ),
            const SizedBox(height: 16),
            _fotoSection(),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _loading ? null : _submit,
              icon: _loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                    )
                  : const Icon(Icons.send),
              label: const Text('Kirim Pengaduan'),
            ),
          ],
        ),
      ),
    );
  }
}
