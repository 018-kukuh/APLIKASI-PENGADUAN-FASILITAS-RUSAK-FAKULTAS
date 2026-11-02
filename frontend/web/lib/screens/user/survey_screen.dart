import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../../services/api_service.dart';
import '../../widgets/common.dart';
import '../../widgets/satisfaction_pie.dart';
import '../../widgets/survey_form.dart';

/// Fitur 4: survei kepuasan + grafik lingkaran live.
/// Pengaduan bisa disurvei jika sudah ditangani ATAU sudah melewati batas 1 hari.
class SurveyScreen extends StatefulWidget {
  const SurveyScreen({super.key});

  @override
  State<SurveyScreen> createState() => _SurveyScreenState();
}

class _SurveyScreenState extends State<SurveyScreen> {
  late Future<List<Complaint>> _future = ApiService.instance.myComplaints();
  Key _pieKey = UniqueKey();

  Future<void> _reload() async {
    final f = ApiService.instance.myComplaints();
    setState(() {
      _future = f;
      _pieKey = UniqueKey(); // paksa grafik mengambil data terbaru
    });
    try {
      await f;
    } catch (_) {}
  }

  Future<void> _isiSurvei(Complaint c) async {
    final ok = await showSurveyForm(context, c);
    if (ok && mounted) _reload();
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _reload,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          SatisfactionPie(key: _pieKey),
          const SizedBox(height: 20),
          const Text('Pengaduan yang bisa disurvei',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(
            'Muncul setelah pengaduan ditangani, atau jika melewati batas 1 hari walau belum ditangani.',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 10),
          FutureBuilder<List<Complaint>>(
            future: _future,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (snap.hasError) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text(snap.error.toString()),
                );
              }
              final eligible = snap.data!.where((c) => c.bisaSurvei).toList();
              if (eligible.isEmpty) {
                return const EmptyState('Belum ada pengaduan yang dapat disurvei.',
                    icon: Icons.rate_review_outlined);
              }
              return Column(
                children: eligible
                    .map((c) => ComplaintCard(
                          complaint: c,
                          onTap: () => _isiSurvei(c),
                        ))
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}
