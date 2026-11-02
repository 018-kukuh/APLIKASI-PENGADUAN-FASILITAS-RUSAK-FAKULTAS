import 'dart:async';

import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/api_service.dart';
import '../widgets/common.dart';
import 'fakultas/complaint_manage_page.dart';
import 'track_screen.dart';

/// Beranda informasi laporan (semua role): SEMUA laporan yang masih berjalan dari
/// mahasiswa & dosen. Pelapor bisa mengecek apakah kerusakan yang sama sudah
/// dilaporkan, dan melihat statusnya (ketuk kartu untuk detail & foto).
/// Nama pelapor hanya terlihat oleh Fakultas.
///
/// Laporan otomatis hilang dari beranda begitu statusnya Selesai atau Ditolak
/// (riwayatnya tetap ada di menu Riwayat / Pengaduan).
class HomeScreen extends StatefulWidget {
  final bool fakultas;
  final VoidCallback? onBuatPengaduan; // hanya untuk mahasiswa/dosen
  const HomeScreen({super.key, required this.fakultas, this.onBuatPengaduan});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Complaint>? _list;
  String? _error;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _load();
    // Segarkan otomatis supaya laporan yang selesai/ditolak langsung hilang.
    _timer = Timer.periodic(const Duration(seconds: 10), (_) => _load());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final l = await ApiService.instance.activeComplaints();
      if (!mounted) return;
      setState(() {
        _list = l;
        _error = null;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    }
  }

  Future<void> _open(Complaint c) async {
    if (widget.fakultas) {
      await Navigator.push<bool>(
        context,
        MaterialPageRoute(builder: (_) => ComplaintManagePage(complaint: c)),
      );
    } else {
      await openComplaintDetail(context, c.kode);
    }
    if (mounted) _load();
  }

  Widget _summary(List<Complaint> list) {
    final menunggu = list.where((c) => c.status == 'menunggu').length;
    final diproses = list.where((c) => c.status == 'diproses').length;
    final lewat = list.where((c) => c.lewatBatas).length;
    Widget item(String label, int n, Color color) => Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: color.withAlpha(25),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Text('$n',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: color)),
                const SizedBox(height: 2),
                Text(label, style: TextStyle(fontSize: 12, color: color)),
              ],
            ),
          ),
        );
    return Row(
      children: [
        item('Menunggu', menunggu, statusColor('menunggu')),
        const SizedBox(width: 8),
        item('Diproses', diproses, statusColor('diproses')),
        const SizedBox(width: 8),
        item('Lewat batas', lewat, const Color(0xFFDC2626)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final list = _list;
    Widget body;
    if (list == null && _error == null) {
      body = const Center(child: CircularProgressIndicator());
    } else if (list == null) {
      body = ErrorState(message: _error!, onRetry: _load);
    } else {
      body = RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFDBEAFE),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.fakultas
                          ? 'Laporan masuk yang belum selesai. Laporan hilang dari beranda setelah berstatus Selesai atau Ditolak.'
                          : 'Laporan dari seluruh mahasiswa & dosen yang sedang berjalan. Cek dulu sebelum membuat laporan agar tidak dobel. Laporan hilang setelah Selesai atau Ditolak.',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            _summary(list),
            const SizedBox(height: 16),
            Text(
              'Laporan berjalan (${list.length})',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            if (list.isEmpty) ...[
              EmptyState(
                widget.fakultas
                    ? 'Tidak ada laporan yang sedang berjalan.'
                    : 'Belum ada laporan yang sedang berjalan.\nLaporan Anda yang sudah selesai atau ditolak ada di menu Riwayat.',
                icon: Icons.task_alt,
              ),
              if (!widget.fakultas && widget.onBuatPengaduan != null)
                Center(
                  child: FilledButton.icon(
                    onPressed: widget.onBuatPengaduan,
                    icon: const Icon(Icons.add),
                    label: const Text('Buat Pengaduan'),
                  ),
                ),
            ] else
              ...list.map((c) => ComplaintCard(
                    complaint: c,
                    showPelapor: widget.fakultas,
                    onTap: () => _open(c),
                  )),
          ],
        ),
      );
    }
    return body;
  }
}
