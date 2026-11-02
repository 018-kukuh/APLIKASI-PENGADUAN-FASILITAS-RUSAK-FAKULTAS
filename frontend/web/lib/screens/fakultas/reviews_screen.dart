import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../../services/api_service.dart';
import '../../widgets/common.dart';
import '../../widgets/satisfaction_pie.dart';

/// Fitur 4 (Fakultas): grafik kepuasan live + daftar ulasan/keterangan dari pelapor.
class ReviewsScreen extends StatefulWidget {
  const ReviewsScreen({super.key});

  @override
  State<ReviewsScreen> createState() => _ReviewsScreenState();
}

class _ReviewsScreenState extends State<ReviewsScreen> {
  late Future<List<ReviewItem>> _future = ApiService.instance.surveys();
  Key _pieKey = UniqueKey();

  Future<void> _reload() async {
    final f = ApiService.instance.surveys();
    setState(() {
      _future = f;
      _pieKey = UniqueKey();
    });
    try {
      await f;
    } catch (_) {}
  }

  Widget _item(ReviewItem r) {
    final info = ratingInfo(r.rating);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(info.icon, color: info.color, size: 32),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(info.label,
                      style: TextStyle(fontWeight: FontWeight.w800, color: info.color)),
                  const SizedBox(height: 2),
                  Text(
                    (r.keterangan == null || r.keterangan!.isEmpty) ? '(tanpa keterangan)' : r.keterangan!,
                    style: TextStyle(
                      fontStyle: (r.keterangan == null || r.keterangan!.isEmpty)
                          ? FontStyle.italic
                          : FontStyle.normal,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text('${r.pelaporNama} (${roleLabel(r.pelaporRole)}) · ${r.kode}',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                  Text(r.judul, style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                  Text(fmtDate(r.createdAt),
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
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
          const Text('Ulasan Pengguna', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          FutureBuilder<List<ReviewItem>>(
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
              final list = snap.data!;
              if (list.isEmpty) {
                return const EmptyState('Belum ada ulasan masuk.', icon: Icons.rate_review_outlined);
              }
              return Column(children: list.map(_item).toList());
            },
          ),
        ],
      ),
    );
  }
}
