import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/api_service.dart';
import '../widgets/common.dart';
import '../widgets/survey_form.dart';

/// Membuka halaman detail pengaduan (dipakai dari daftar riwayat / daftar fakultas).
Future<void> openComplaintDetail(BuildContext context, String kode) {
  return Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => Scaffold(
        appBar: AppBar(title: const Text('Detail Pengaduan')),
        body: TrackScreen(initialKode: kode),
      ),
    ),
  );
}

/// Fitur "Lacak Pengaduan": masukkan kode unik, lihat status & riwayat.
/// Dipakai oleh semua role.
class TrackScreen extends StatefulWidget {
  final String? initialKode;
  const TrackScreen({super.key, this.initialKode});

  @override
  State<TrackScreen> createState() => _TrackScreenState();
}

class _TrackScreenState extends State<TrackScreen> {
  final _kode = TextEditingController();
  bool _loading = false;
  String? _error;
  TrackResult? _result;

  @override
  void initState() {
    super.initState();
    if (widget.initialKode != null) {
      _kode.text = widget.initialKode!;
      _search();
    }
  }

  @override
  void dispose() {
    _kode.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final k = _kode.text.trim();
    if (k.isEmpty) {
      setState(() => _error = 'Masukkan kode pengaduan');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final r = await ApiService.instance.track(k);
      if (!mounted) return;
      setState(() {
        _result = r;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _result = null;
        _error = e.message;
        _loading = false;
      });
    }
  }

  Future<void> _isiSurvei(Complaint c) async {
    final ok = await showSurveyForm(context, c);
    if (ok && mounted) _search();
  }

  @override
  Widget build(BuildContext context) {
    final r = _result;
    return RefreshIndicator(
      onRefresh: () async {
        if (_kode.text.trim().isNotEmpty) await _search();
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          if (widget.initialKode == null)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextField(
                  controller: _kode,
                  textCapitalization: TextCapitalization.characters,
                  onSubmitted: (_) => _search(),
                  decoration: const InputDecoration(
                    labelText: 'Kode pengaduan',
                    hintText: 'contoh: ADU-261027-JZNEC',
                    prefixIcon: Icon(Icons.qr_code_2),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                height: 56,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(64, 56),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _loading ? null : _search,
                  child: _loading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                        )
                      : const Icon(Icons.search),
                ),
              ),
            ],
          ),
          if (widget.initialKode == null) const SizedBox(height: 16),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: EmptyState(_error!, icon: Icons.search_off),
            ),
          if (r == null && _error == null && !_loading && widget.initialKode == null)
            const EmptyState(
              'Masukkan kode unik pengaduan untuk melihat status dan riwayat penanganannya.',
              icon: Icons.manage_search,
            ),
          if (r != null) ...[
            ComplaintInfo(complaint: r.complaint),
            const SizedBox(height: 16),
            _surveySection(r.complaint),
            const SizedBox(height: 16),
            const Text('Riwayat Status', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            ...r.riwayat.map(_logTile),
          ],
        ],
      ),
    );
  }

  Widget _surveySection(Complaint c) {
    if (!c.milikSaya) return const SizedBox.shrink();
    if (c.sudahSurvei) {
      return const Row(
        children: [
          Icon(Icons.check_circle, color: Color(0xFF16A34A)),
          SizedBox(width: 8),
          Expanded(child: Text('Anda sudah mengisi survei kepuasan untuk pengaduan ini.')),
        ],
      );
    }
    if (c.bisaSurvei) {
      return FilledButton.icon(
        onPressed: () => _isiSurvei(c),
        icon: const Icon(Icons.rate_review_outlined),
        label: const Text('Isi Survei Kepuasan'),
      );
    }
    return Text(
      'Survei kepuasan dapat diisi setelah pengaduan ditangani, atau jika sudah melewati batas penanganan 1 hari.',
      style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
    );
  }

  Widget _logTile(TrackLog l) {
    final color = statusColor(l.status);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Icon(Icons.circle, size: 12, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(statusLabels[l.status] ?? l.status,
                    style: TextStyle(fontWeight: FontWeight.w700, color: color)),
                if (l.catatan != null && l.catatan!.isNotEmpty) Text(l.catatan!),
                Text(fmtDate(l.createdAt),
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
