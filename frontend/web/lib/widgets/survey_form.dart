import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/api_service.dart';
import 'common.dart';

/// Menampilkan form survei kepuasan. Mengembalikan true jika survei terkirim.
Future<bool> showSurveyForm(BuildContext context, Complaint complaint) async {
  final res = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _SurveyForm(complaint: complaint),
  );
  return res == true;
}

class _SurveyForm extends StatefulWidget {
  final Complaint complaint;
  const _SurveyForm({required this.complaint});

  @override
  State<_SurveyForm> createState() => _SurveyFormState();
}

class _SurveyFormState extends State<_SurveyForm> {
  String? _rating;
  final _ket = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _ket.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_rating == null) {
      showSnack(context, 'Pilih salah satu penilaian terlebih dahulu');
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    setState(() => _loading = true);
    try {
      await ApiService.instance.submitSurvey(widget.complaint.id, _rating!, _ket.text);
      nav.pop(true);
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Terima kasih, survei berhasil dikirim')));
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      showSnack(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.complaint;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Survei Kepuasan',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text('${c.kode} · ${c.judul}', style: TextStyle(color: Colors.grey.shade700)),
            if (!c.selesaiDitangani) ...[
              const SizedBox(height: 8),
              Text(
                'Pengaduan ini belum ditangani dan sudah melewati batas 1 hari. Anda tetap dapat memberi penilaian.',
                style: TextStyle(color: Colors.orange.shade800, fontSize: 13),
              ),
            ],
            const SizedBox(height: 16),
            const Text('Bagaimana penanganan pengaduan Anda?',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            Row(
              children: ratingInfos.map((r) {
                final selected = _rating == r.key;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: _loading ? null : () => setState(() => _rating = r.key),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: selected ? r.color.withAlpha(35) : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: selected ? r.color : Colors.grey.shade300,
                            width: selected ? 2 : 1,
                          ),
                        ),
                        child: Column(
                          children: [
                            Icon(r.icon, size: 34, color: r.color),
                            const SizedBox(height: 6),
                            Text(r.label,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                                    fontSize: 13)),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _ket,
              maxLength: 500,
              maxLines: 3,
              enabled: !_loading,
              decoration: const InputDecoration(
                labelText: 'Keterangan (opsional)',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: _loading ? null : _submit,
              child: _loading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                    )
                  : const Text('Kirim Survei'),
            ),
          ],
        ),
      ),
    );
  }
}
