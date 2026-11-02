import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../../services/api_service.dart';
import '../../widgets/common.dart';
import '../../theme.dart';
import '../../widgets/satisfaction_pie.dart';

/// Fitur 1 (Fakultas): ringkasan jumlah pengaduan + grafik kepuasan live.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Dashboard? _data;
  String? _error;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(const Duration(seconds: 10), (_) => _load());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final d = await ApiService.instance.dashboard();
      if (!mounted) return;
      setState(() {
        _data = d;
        _error = null;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    }
  }

  // Kartu statistik: ikon bulat di atas, angka besar, label kecil. Tinggi tetap, lebar menyesuaikan.
  Widget _tile(String label, int value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [BoxShadow(color: color.withAlpha(22), blurRadius: 16, offset: const Offset(0, 6))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withAlpha(28), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: color, size: 20),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$value', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, height: 1.1)),
              const SizedBox(height: 2),
              Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12.5, color: Colors.grey.shade700, fontWeight: FontWeight.w500)),
            ],
          ),
        ],
      ),
    );
  }

  // Banner ringkasan di atas dashboard.
  Widget _banner(Dashboard d) {
    final selesaiPct = d.total == 0 ? 0 : (d.selesai * 100 / d.total).round();
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [kNavy, kNavyLight],
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [BoxShadow(color: kNavy.withAlpha(50), blurRadius: 22, offset: const Offset(0, 10))],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Total pengaduan masuk',
                    style: TextStyle(color: Colors.white.withAlpha(200), fontSize: 13.5, fontWeight: FontWeight.w500)),
                const SizedBox(height: 4),
                Text('${d.total}',
                    style: const TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.w800, height: 1.1)),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: kGold, borderRadius: BorderRadius.circular(20)),
                  child: Text('$selesaiPct% sudah selesai',
                      style: const TextStyle(color: kNavy, fontSize: 12, fontWeight: FontWeight.w800)),
                ),
              ],
            ),
          ),
          Icon(Icons.assignment_outlined, size: 72, color: Colors.white.withAlpha(40)),
        ],
      ),
    );
  }

  // Rincian status berupa batang horizontal (persen dari total).
  Widget _distribusi(Dashboard d) {
    final rows = <(String, int, Color)>[
      ('Menunggu', d.menunggu, statusColor('menunggu')),
      ('Diproses', d.diproses, statusColor('diproses')),
      ('Selesai', d.selesai, statusColor('selesai')),
      ('Ditolak', d.ditolak, statusColor('ditolak')),
    ];
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Status Pengaduan', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 14),
          for (final r in rows)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(r.$1, style: const TextStyle(fontWeight: FontWeight.w600))),
                      Text('${r.$2}', style: const TextStyle(fontWeight: FontWeight.w800)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: d.total == 0 ? 0 : r.$2 / d.total,
                      minHeight: 8,
                      color: r.$3,
                      backgroundColor: r.$3.withAlpha(30),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final d = _data;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: ConstrainedBox(
              // Batasi lebar supaya di layar lebar (web/tablet) kartu tidak melebar raksasa.
              constraints: const BoxConstraints(maxWidth: 1000),
              child: d == null && _error == null
                  ? const Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : d == null
                      ? ErrorState(message: _error!, onRetry: _load)
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _banner(d),
                            const SizedBox(height: 16),
                            GridView(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                                maxCrossAxisExtent: 220,
                                mainAxisExtent: 118,
                                mainAxisSpacing: 12,
                                crossAxisSpacing: 12,
                              ),
                              children: [
                                _tile('Menunggu', d.menunggu, statusColor('menunggu'), Icons.hourglass_empty),
                                _tile('Diproses', d.diproses, statusColor('diproses'), Icons.build_outlined),
                                _tile('Selesai', d.selesai, statusColor('selesai'), Icons.check_circle_outline),
                                _tile('Ditolak', d.ditolak, statusColor('ditolak'), Icons.cancel_outlined),
                                _tile('Lewat batas 1 hari', d.lewatBatas, const Color(0xFFDC2626), Icons.schedule),
                              ],
                            ),
                            const SizedBox(height: 16),
                            LayoutBuilder(builder: (context, c) {
                              if (c.maxWidth >= 720) {
                                return Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(child: _distribusi(d)),
                                    const SizedBox(width: 16),
                                    const Expanded(child: SatisfactionPie()),
                                  ],
                                );
                              }
                              return Column(
                                children: [
                                  _distribusi(d),
                                  const SizedBox(height: 16),
                                  const SatisfactionPie(),
                                ],
                              );
                            }),
                          ],
                        ),
            ),
          ),
        ],
      ),
    );
  }
}
