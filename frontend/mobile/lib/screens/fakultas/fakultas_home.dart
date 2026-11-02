import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../widgets/common.dart';
import '../home_screen.dart';
import '../track_screen.dart';
import 'accounts_screen.dart';
import 'complaints_screen.dart';
import 'dashboard_screen.dart';
import 'reviews_screen.dart';

/// Beranda role Fakultas. 6 menu: 0) Beranda (info laporan masuk yang berjalan)
/// 1) Dashboard & grafik live  2) Kelola Pengaduan (ubah status)  3) Lacak Kode  4) Ulasan Survei
/// 5) Kelola Akun mahasiswa & dosen (perbarui data, reset sandi)
class FakultasHome extends StatefulWidget {
  const FakultasHome({super.key});

  @override
  State<FakultasHome> createState() => _FakultasHomeState();
}

class _FakultasHomeState extends State<FakultasHome> {
  int _index = 0;

  static const _titles = ['Beranda', 'Dashboard', 'Kelola Pengaduan', 'Lacak Pengaduan', 'Ulasan Survei', 'Kelola Akun'];

  Widget _body() {
    switch (_index) {
      case 0:
        return const HomeScreen(fakultas: true);
      case 1:
        return const DashboardScreen();
      case 2:
        return const ComplaintsScreen();
      case 3:
        return const TrackScreen();
      case 4:
        return const ReviewsScreen();
      default:
        return const AccountsScreen();
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
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: 'Dashboard'),
          NavigationDestination(icon: Icon(Icons.list_alt), label: 'Pengaduan'),
          NavigationDestination(icon: Icon(Icons.search), label: 'Lacak'),
          NavigationDestination(icon: Icon(Icons.rate_review_outlined), selectedIcon: Icon(Icons.rate_review), label: 'Ulasan'),
          NavigationDestination(icon: Icon(Icons.manage_accounts_outlined), selectedIcon: Icon(Icons.manage_accounts), label: 'Akun'),
        ],
      ),
    );
  }
}
