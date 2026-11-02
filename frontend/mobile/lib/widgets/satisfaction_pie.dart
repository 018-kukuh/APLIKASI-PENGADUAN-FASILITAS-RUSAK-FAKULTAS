import 'dart:async';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/api_service.dart';
import 'common.dart';

/// Grafik lingkaran kepuasan (Sangat Baik / Baik / Kurang) beserta persennya.
/// Data diambil ulang otomatis setiap [interval] sehingga grafik terasa "live".
class SatisfactionPie extends StatefulWidget {
  final Duration interval;
  const SatisfactionPie({super.key, this.interval = const Duration(seconds: 5)});

  @override
  State<SatisfactionPie> createState() => _SatisfactionPieState();
}

class _SatisfactionPieState extends State<SatisfactionPie> {
  SurveyStats? _stats;
  String? _error;
  DateTime? _updated;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(widget.interval, (_) => _load());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final s = await ApiService.instance.surveyStats();
      if (!mounted) return;
      setState(() {
        _stats = s;
        _error = null;
        _updated = DateTime.now();
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    }
  }

  List<PieChartSectionData> _sections(SurveyStats s) {
    if (s.total == 0) {
      return [
        PieChartSectionData(value: 1, color: Colors.grey.shade300, title: '', radius: 54),
      ];
    }
    return ratingInfos.map((r) {
      final st = s.byKey(r.key);
      return PieChartSectionData(
        value: st.jumlah.toDouble(),
        color: r.color,
        radius: 54,
        showTitle: st.jumlah > 0,
        title: '${fmtPct(st.persen)}%',
        titleStyle: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: 14,
        ),
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final s = _stats;
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text('Kepuasan Pengguna',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                ),
                const _LiveBadge(),
              ],
            ),
            const SizedBox(height: 16),
            if (s == null && _error == null)
              const SizedBox(height: 200, child: Center(child: CircularProgressIndicator()))
            else if (s == null)
              SizedBox(
                height: 200,
                child: Center(child: Text(_error!, textAlign: TextAlign.center)),
              )
            else ...[
              SizedBox(
                height: 200,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    PieChart(
                      PieChartData(
                        sectionsSpace: s.total == 0 ? 0 : 2,
                        centerSpaceRadius: 52,
                        sections: _sections(s),
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('${s.total}',
                            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
                        Text('survei', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              if (s.total == 0)
                Center(
                  child: Text('Belum ada survei masuk',
                      style: TextStyle(color: Colors.grey.shade600)),
                ),
              ...ratingInfos.map((r) {
                final st = s.byKey(r.key);
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(color: r.color, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: Text(r.label)),
                      Text('${st.jumlah} suara · ${fmtPct(st.persen)}%',
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                    ],
                  ),
                );
              }),
              if (_updated != null) ...[
                const SizedBox(height: 6),
                Text(
                  'Diperbarui otomatis tiap ${widget.interval.inSeconds} detik · terakhir ${_updated!.hour.toString().padLeft(2, '0')}:${_updated!.minute.toString().padLeft(2, '0')}:${_updated!.second.toString().padLeft(2, '0')}',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _LiveBadge extends StatelessWidget {
  const _LiveBadge();

  @override
  Widget build(BuildContext context) {
    const red = Color(0xFFDC2626);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: red.withAlpha(25),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, size: 8, color: red),
          SizedBox(width: 4),
          Text('LIVE', style: TextStyle(color: red, fontSize: 11, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}
