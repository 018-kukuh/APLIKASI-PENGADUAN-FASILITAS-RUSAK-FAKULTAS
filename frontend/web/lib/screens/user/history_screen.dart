import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../../services/api_service.dart';
import '../../widgets/common.dart';
import '../track_screen.dart';

/// Fitur 3: riwayat pengaduan milik sendiri.
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  late Future<List<Complaint>> _future = ApiService.instance.myComplaints();

  Future<void> _reload() async {
    final f = ApiService.instance.myComplaints();
    setState(() => _future = f);
    try {
      await f;
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Complaint>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return ErrorState(message: snap.error.toString(), onRetry: _reload);
        }
        final list = snap.data!;
        return RefreshIndicator(
          onRefresh: _reload,
          child: list.isEmpty
              ? ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: const [
                    SizedBox(height: 120),
                    EmptyState('Belum ada pengaduan. Buat pengaduan pertama Anda di tab "Buat".'),
                  ],
                )
              : ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  itemCount: list.length,
                  itemBuilder: (_, i) {
                    final c = list[i];
                    return ComplaintCard(
                      complaint: c,
                      onTap: () async {
                        await openComplaintDetail(context, c.kode);
                        if (mounted) _reload();
                      },
                    );
                  },
                ),
        );
      },
    );
  }
}
