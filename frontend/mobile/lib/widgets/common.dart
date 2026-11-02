import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../theme.dart';

// ------------------------------------------------------------------ Format
String fmtDate(DateTime d) => DateFormat('d MMM y, HH:mm', 'id_ID').format(d);

String fmtPct(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

void showSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

String roleLabel(String role) {
  switch (role) {
    case 'mahasiswa':
      return 'Mahasiswa';
    case 'dosen':
      return 'Dosen';
    case 'fakultas':
      return 'Fakultas';
    default:
      return role;
  }
}

// ------------------------------------------------------------------ Status
const statusLabels = {
  'menunggu': 'Menunggu',
  'diproses': 'Diproses',
  'selesai': 'Selesai',
  'ditolak': 'Ditolak',
};

Color statusColor(String status) {
  switch (status) {
    case 'menunggu':
      return const Color(0xFFD97706);
    case 'diproses':
      return const Color(0xFF2563EB);
    case 'selesai':
      return const Color(0xFF16A34A);
    case 'ditolak':
      return const Color(0xFFDC2626);
    default:
      return Colors.grey;
  }
}

class StatusChip extends StatelessWidget {
  final String status;
  const StatusChip(this.status, {super.key});

  @override
  Widget build(BuildContext context) {
    final c = statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: c.withAlpha(30),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        statusLabels[status] ?? status,
        style: TextStyle(color: c, fontWeight: FontWeight.w600, fontSize: 12),
      ),
    );
  }
}

String batasText(Complaint c) {
  if (c.selesaiDitangani) return 'Sudah ditangani';
  final now = DateTime.now();
  if (now.isAfter(c.batasWaktu)) return 'Melewati batas 1 hari (${fmtDate(c.batasWaktu)})';
  final sisa = c.batasWaktu.difference(now);
  return 'Sisa waktu penanganan ${sisa.inHours} jam ${sisa.inMinutes % 60} menit';
}

// ------------------------------------------------------------------ Rating
class RatingInfo {
  final String key;
  final String label;
  final Color color;
  final IconData icon;
  const RatingInfo(this.key, this.label, this.color, this.icon);
}

const ratingInfos = [
  RatingInfo('sangat_baik', 'Sangat Baik', Color(0xFF22C55E), Icons.sentiment_very_satisfied),
  RatingInfo('baik', 'Baik', Color(0xFF3B82F6), Icons.sentiment_satisfied),
  RatingInfo('kurang', 'Kurang', Color(0xFFF97316), Icons.sentiment_dissatisfied),
];

RatingInfo ratingInfo(String key) => ratingInfos.firstWhere((r) => r.key == key);

// -------------------------------------------------------------------- Logo
class LogoMark extends StatelessWidget {
  final double size;
  const LogoMark({super.key, this.size = 40});

  @override
  Widget build(BuildContext context) =>
      Image.asset('assets/images/logo.png', width: size, height: size, fit: BoxFit.contain);
}

/// AppBar seragam untuk semua beranda: logo + judul halaman + nama pengguna.
class AppHeader extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final String subtitle;
  const AppHeader({super.key, required this.title, required this.subtitle});

  @override
  Size get preferredSize => const Size.fromHeight(72);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      toolbarHeight: 69,
      backgroundColor: kNavy,
      foregroundColor: Colors.white,
      leadingWidth: 64,
      leading: const Padding(
        padding: EdgeInsets.only(left: 14),
        child: Center(child: LogoMark(size: 40)),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
          Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.white70)),
        ],
      ),
      actions: const [LogoutButton(), SizedBox(width: 4)],
      bottom: const PreferredSize(
        preferredSize: Size.fromHeight(3),
        child: SizedBox(height: 3, width: double.infinity, child: ColoredBox(color: kGold)),
      ),
    );
  }
}

// ------------------------------------------------------------ Logout button
class LogoutButton extends StatelessWidget {
  const LogoutButton({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.logout),
      tooltip: 'Keluar',
      onPressed: () async {
        final ok = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Keluar'),
            content: const Text('Yakin ingin keluar dari akun?'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
              FilledButton(
                style: FilledButton.styleFrom(minimumSize: const Size(80, 40)),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Keluar'),
              ),
            ],
          ),
        );
        if (ok == true && context.mounted) {
          Navigator.of(context).popUntil((r) => r.isFirst);
          context.read<AuthProvider>().logout();
        }
      },
    );
  }
}

// ----------------------------------------------------------- State widgets
class EmptyState extends StatelessWidget {
  final String message;
  final IconData icon;
  const EmptyState(this.message, {super.key, this.icon = Icons.inbox_outlined});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 56, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade600)),
        ],
      ),
    );
  }
}

class ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const ErrorState({super.key, required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off, size: 56, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onRetry, child: const Text('Coba lagi')),
          ],
        ),
      ),
    );
  }
}

// ----------------------------------------------------------- Complaint card
class ComplaintCard extends StatelessWidget {
  final Complaint complaint;
  final VoidCallback? onTap;
  final bool showPelapor;
  const ComplaintCard({super.key, required this.complaint, this.onTap, this.showPelapor = false});

  @override
  Widget build(BuildContext context) {
    final c = complaint;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1.5,
      shadowColor: Colors.black26,
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(c.kode,
                        style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.w700)),
                  ),
                  StatusChip(c.status),
                ],
              ),
              const SizedBox(height: 8),
              Text(c.judul, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.place_outlined, size: 16, color: Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Expanded(child: Text(c.lokasi, style: TextStyle(color: Colors.grey.shade700))),
                ],
              ),
              if (showPelapor && c.pelaporNama != null) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.person_outline, size: 16, color: Colors.grey.shade600),
                    const SizedBox(width: 4),
                    Text('${c.pelaporNama} (${roleLabel(c.pelaporRole ?? '')})',
                        style: TextStyle(color: Colors.grey.shade700)),
                  ],
                ),
              ],
              const SizedBox(height: 6),
              Text(
                fmtDate(c.createdAt),
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              if (c.milikSaya) ...[
                const SizedBox(height: 6),
                const Row(
                  children: [
                    Icon(Icons.person, size: 16, color: Color(0xFF2563EB)),
                    SizedBox(width: 4),
                    Text('Laporan saya',
                        style: TextStyle(fontSize: 12, color: Color(0xFF2563EB), fontWeight: FontWeight.w600)),
                  ],
                ),
              ],
              if (c.fotoUrls.isNotEmpty) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.photo_outlined, size: 16, color: Colors.grey.shade600),
                    const SizedBox(width: 4),
                    Text('${c.fotoUrls.length} foto',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                  ],
                ),
              ],
              if (c.lewatBatas) ...[
                const SizedBox(height: 6),
                const Row(
                  children: [
                    Icon(Icons.schedule, size: 16, color: Color(0xFFDC2626)),
                    SizedBox(width: 4),
                    Text('Melewati batas 1 hari',
                        style: TextStyle(color: Color(0xFFDC2626), fontSize: 12)),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------- Complaint info
class ComplaintInfo extends StatelessWidget {
  final Complaint complaint;
  const ComplaintInfo({super.key, required this.complaint});

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            const SizedBox(height: 2),
            Text(value, style: const TextStyle(fontSize: 15)),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final c = complaint;
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
                Expanded(
                  child: Text(c.kode,
                      style: const TextStyle(
                          fontFamily: 'monospace', fontWeight: FontWeight.w800, fontSize: 18)),
                ),
                IconButton(
                  tooltip: 'Salin kode',
                  icon: const Icon(Icons.copy, size: 20),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: c.kode));
                    showSnack(context, 'Kode disalin');
                  },
                ),
                StatusChip(c.status),
              ],
            ),
            const Divider(height: 24),
            _row('Judul', c.judul),
            _row('Lokasi', c.lokasi),
            _row('Deskripsi', c.deskripsi),
            if (c.fotoUrls.isNotEmpty) ...[
              Text('Foto pengaduan', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
              const SizedBox(height: 6),
              ComplaintPhotos(c.fotoUrls),
              const SizedBox(height: 10),
            ],
            if (c.pelaporNama != null)
              _row('Pelapor', '${c.pelaporNama} (${roleLabel(c.pelaporRole ?? '')})'),
            _row('Dibuat', fmtDate(c.createdAt)),
            _row('Batas penanganan', '${fmtDate(c.batasWaktu)}\n${batasText(c)}'),
            if (c.catatanFakultas != null && c.catatanFakultas!.isNotEmpty)
              _row('Catatan fakultas', c.catatanFakultas!),
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------------------ Foto pengaduan
/// Deretan thumbnail foto lampiran. Ketuk untuk memperbesar.
class ComplaintPhotos extends StatelessWidget {
  final List<String> urls;
  const ComplaintPhotos(this.urls, {super.key});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final u in urls)
          _FotoTile(
            url: u,
            onTap: () => showDialog<void>(
              context: context,
              builder: (_) => _FotoViewer(url: u),
            ),
          ),
      ],
    );
  }
}

class _FotoTile extends StatelessWidget {
  final String url;
  final VoidCallback onTap;
  const _FotoTile({required this.url, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
          width: 96,
          height: 96,
          child: FutureBuilder<Uint8List>(
            future: ApiService.instance.fetchFoto(url),
            builder: (context, snap) {
              if (snap.hasError) {
                return ColoredBox(
                  color: Colors.grey.shade200,
                  child: const Icon(Icons.broken_image_outlined, color: Colors.grey),
                );
              }
              if (!snap.hasData) {
                return ColoredBox(
                  color: Colors.grey.shade200,
                  child: const Center(
                    child: SizedBox(
                        width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                  ),
                );
              }
              return Image.memory(snap.data!, fit: BoxFit.cover);
            },
          ),
        ),
      ),
    );
  }
}

class _FotoViewer extends StatelessWidget {
  final String url;
  const _FotoViewer({required this.url});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(12),
      backgroundColor: Colors.black,
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.75,
        child: Stack(
          children: [
          Positioned.fill(
            child: FutureBuilder<Uint8List>(
              future: ApiService.instance.fetchFoto(url),
              builder: (context, snap) {
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                return InteractiveViewer(
                  minScale: 1,
                  maxScale: 5,
                  child: Image.memory(snap.data!, fit: BoxFit.contain),
                );
              },
            ),
          ),
          Positioned(
            top: 4,
            right: 4,
            child: IconButton(
              color: Colors.white,
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ],
        ),
      ),
    );
  }
}
