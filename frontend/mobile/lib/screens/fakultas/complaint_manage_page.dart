import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../../services/api_service.dart';
import '../../widgets/common.dart';

/// Halaman detail + form ubah status pengaduan (role Fakultas).
class ComplaintManagePage extends StatefulWidget {
  final Complaint complaint;
  const ComplaintManagePage({super.key, required this.complaint});

  @override
  State<ComplaintManagePage> createState() => _ComplaintManagePageState();
}

class _ComplaintManagePageState extends State<ComplaintManagePage> {
  late Complaint _c = widget.complaint;
  late String _status = widget.complaint.status;
  final _catatan = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _catatan.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _loading = true);
    try {
      final updated = await ApiService.instance.updateStatus(_c.id, _status, _catatan.text.trim());
      if (!mounted) return;
      setState(() {
        _c = updated;
        _loading = false;
        _catatan.clear();
      });
      showSnack(context, 'Status diperbarui menjadi ${statusLabels[updated.status]}');
      Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      showSnack(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Kelola Pengaduan')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ComplaintInfo(complaint: _c),
          const SizedBox(height: 20),
          const Text('Ubah Status', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            value: _status,
            decoration: const InputDecoration(labelText: 'Status'),
            items: statusLabels.entries
                .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                .toList(),
            onChanged: _loading ? null : (v) => setState(() => _status = v ?? _status),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _catatan,
            minLines: 2,
            maxLines: 5,
            enabled: !_loading,
            decoration: const InputDecoration(
              labelText: 'Catatan untuk pelapor (opsional)',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 18),
          FilledButton(
            onPressed: _loading ? null : _save,
            child: _loading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                  )
                : const Text('Simpan'),
          ),
        ],
      ),
    );
  }
}
