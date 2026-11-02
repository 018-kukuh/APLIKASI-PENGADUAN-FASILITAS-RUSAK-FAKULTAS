import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../../services/api_service.dart';
import '../../widgets/common.dart';
import 'complaint_manage_page.dart';

/// Fitur 2 (Fakultas): pengaduan masuk, dipisah menurut status.
/// Selesai/Ditolak tetap tampil di tab statusnya selama 24 jam, setelah itu
/// otomatis pindah ke tab Riwayat.
class ComplaintsScreen extends StatefulWidget {
  const ComplaintsScreen({super.key});

  @override
  State<ComplaintsScreen> createState() => _ComplaintsScreenState();
}

class _ComplaintsScreenState extends State<ComplaintsScreen> {
  String _filter = 'semua';
  late Future<List<Complaint>> _future = ApiService.instance.allComplaints(status: _filter);

  Future<void> _reload() async {
    final f = ApiService.instance.allComplaints(status: _filter);
    setState(() => _future = f);
    try {
      await f;
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final filters = ['semua', 'menunggu', 'diproses', 'selesai', 'ditolak', 'riwayat'];
    return Column(
      children: [
        SizedBox(
          height: 52,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            children: filters
                .map((f) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(f == 'semua' ? 'Semua' : f == 'riwayat' ? 'Riwayat' : statusLabels[f]!),
                        selected: _filter == f,
                        onSelected: (_) {
                          _filter = f;
                          _reload();
                        },
                      ),
                    ))
                .toList(),
          ),
        ),
        if (_filter == 'selesai' || _filter == 'ditolak' || _filter == 'riwayat')
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.history, size: 16, color: Colors.grey.shade600),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _filter == 'riwayat'
                        ? 'Pengaduan selesai/ditolak lebih dari 24 jam yang lalu.'
                        : 'Setelah 24 jam berstatus ${statusLabels[_filter]!.toLowerCase()}, pengaduan pindah ke Riwayat.',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ),
              ],
            ),
          ),
        Expanded(
          child: FutureBuilder<List<Complaint>>(
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
                        children: [
                          const SizedBox(height: 100),
                          EmptyState(_filter == 'riwayat' ? 'Belum ada riwayat pengaduan.' : 'Tidak ada pengaduan pada filter ini.'),
                        ],
                      )
                    : ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                        itemCount: list.length,
                        itemBuilder: (_, i) {
                          final c = list[i];
                          return ComplaintCard(
                            complaint: c,
                            showPelapor: true,
                            onTap: () async {
                              final changed = await Navigator.push<bool>(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ComplaintManagePage(complaint: c),
                                ),
                              );
                              if (changed == true && mounted) _reload();
                            },
                          );
                        },
                      ),
              );
            },
          ),
        ),
      ],
    );
  }
}
