import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../widgets/common.dart';
import '../home_screen.dart';
import 'create_complaint_screen.dart';
import 'history_screen.dart';
import 'survey_screen.dart';

/// Beranda untuk role Mahasiswa dan Dosen. 5 menu:
/// 0) Beranda (semua laporan berjalan, milik siapa pun)  1) Buat Pengaduan (+ foto)  2) Riwayat saya  3) Survei & Grafik Kepuasan
/// (fitur Lacak kode hanya untuk Fakultas)
class UserHome extends StatefulWidget {
  const UserHome({super.key});

  @override
  State<UserHome> createState() => _UserHomeState();
}

class _UserHomeState extends State<UserHome> {
  int _index = 0;

  static const _titles = ['Beranda', 'Buat Pengaduan', 'Riwayat Pengaduan', 'Survei Kepuasan'];

  Widget _body() {
    switch (_index) {
      case 0:
        return HomeScreen(fakultas: false, onBuatPengaduan: () => setState(() => _index = 1));
      case 1:
        return CreateComplaintScreen(onGoToHistory: () => setState(() => _index = 2));
      case 2:
        return const HistoryScreen();
      default:
        return const SurveyScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user!;
    return Scaffold(
      appBar: AppHeader(
        title: _titles[_index],
        subtitle: '${user.nama} · ${roleLabel(user.role)}',
      ),
      body: _body(),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Beranda'),
          NavigationDestination(icon: Icon(Icons.add_circle_outline), selectedIcon: Icon(Icons.add_circle), label: 'Buat'),
          NavigationDestination(icon: Icon(Icons.history), label: 'Riwayat'),
          NavigationDestination(icon: Icon(Icons.pie_chart_outline), selectedIcon: Icon(Icons.pie_chart), label: 'Survei'),
        ],
      ),
    );
  }
}
