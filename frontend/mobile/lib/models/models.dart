double _toDouble(dynamic v) => v is num ? v.toDouble() : 0.0;
int _toInt(dynamic v) => v is num ? v.toInt() : 0;

class AppUser {
  final int id;
  final String nama;
  final String email;
  final String role; // mahasiswa | dosen | fakultas
  final String? nomorInduk; // NIM (mahasiswa) / NIDN (dosen) / ID staf (fakultas)
  final String? alamat;

  AppUser({
    required this.id,
    required this.nama,
    required this.email,
    required this.role,
    this.nomorInduk,
    this.alamat,
  });

  factory AppUser.fromJson(Map<String, dynamic> j) => AppUser(
        id: j['id'] as int,
        nama: j['nama'] as String,
        email: j['email'] as String,
        role: j['role'] as String,
        nomorInduk: j['nomor_induk'] as String?,
        alamat: j['alamat'] as String?,
      );
}

class Complaint {
  final int id;
  final String kode;
  final String judul;
  final String lokasi;
  final String deskripsi;
  final String status; // menunggu | diproses | selesai | ditolak
  final String? catatanFakultas;
  final DateTime createdAt;
  final DateTime batasWaktu;
  final bool lewatBatas;
  final bool sudahSurvei;
  final bool bisaSurvei;
  final bool milikSaya;
  final String? pelaporNama;
  final String? pelaporRole;
  final List<String> fotoUrls; // path gambar lampiran, mis. /api/photos/12
  final bool diarsipkan; // selesai/ditolak > 24 jam (masuk Riwayat fakultas)

  Complaint({
    required this.id,
    required this.kode,
    required this.judul,
    required this.lokasi,
    required this.deskripsi,
    required this.status,
    required this.catatanFakultas,
    required this.createdAt,
    required this.batasWaktu,
    required this.lewatBatas,
    required this.sudahSurvei,
    required this.bisaSurvei,
    required this.milikSaya,
    required this.pelaporNama,
    required this.pelaporRole,
    this.fotoUrls = const [],
    this.diarsipkan = false,
  });

  factory Complaint.fromJson(Map<String, dynamic> j) {
    final pelapor = j['pelapor'] as Map<String, dynamic>?;
    return Complaint(
      id: j['id'] as int,
      kode: j['kode'] as String,
      judul: j['judul'] as String,
      lokasi: j['lokasi'] as String,
      deskripsi: j['deskripsi'] as String,
      status: j['status'] as String,
      catatanFakultas: j['catatan_fakultas'] as String?,
      createdAt: DateTime.parse(j['created_at'] as String).toLocal(),
      batasWaktu: DateTime.parse(j['batas_waktu'] as String).toLocal(),
      lewatBatas: j['lewat_batas'] == true,
      sudahSurvei: j['sudah_survei'] == true,
      bisaSurvei: j['bisa_survei'] == true,
      milikSaya: j['milik_saya'] == true,
      pelaporNama: pelapor?['nama'] as String?,
      pelaporRole: pelapor?['role'] as String?,
      fotoUrls: ((j['foto'] as List?) ?? const [])
          .map((e) => (e as Map<String, dynamic>)['url'] as String)
          .toList(),
      diarsipkan: j['diarsipkan'] == true,
    );
  }

  /// Pengaduan sudah ditangani (selesai atau ditolak).
  bool get selesaiDitangani => status == 'selesai' || status == 'ditolak';
}

/// Satu baris riwayat perubahan status (timeline pelacakan).
class TrackLog {
  final String status;
  final String? catatan;
  final DateTime createdAt;

  TrackLog({required this.status, this.catatan, required this.createdAt});

  factory TrackLog.fromJson(Map<String, dynamic> j) => TrackLog(
        status: j['status'] as String,
        catatan: j['catatan'] as String?,
        createdAt: DateTime.parse(j['created_at'] as String).toLocal(),
      );
}

class TrackResult {
  final Complaint complaint;
  final List<TrackLog> riwayat;
  TrackResult(this.complaint, this.riwayat);
}

class RatingStat {
  final int jumlah;
  final double persen;
  const RatingStat(this.jumlah, this.persen);

  factory RatingStat.fromJson(Map<String, dynamic> j) =>
      RatingStat(_toInt(j['jumlah']), _toDouble(j['persen']));
}

class SurveyStats {
  final int total;
  final RatingStat sangatBaik;
  final RatingStat baik;
  final RatingStat kurang;

  const SurveyStats({
    required this.total,
    required this.sangatBaik,
    required this.baik,
    required this.kurang,
  });

  factory SurveyStats.fromJson(Map<String, dynamic> j) => SurveyStats(
        total: _toInt(j['total']),
        sangatBaik: RatingStat.fromJson(j['sangat_baik'] as Map<String, dynamic>),
        baik: RatingStat.fromJson(j['baik'] as Map<String, dynamic>),
        kurang: RatingStat.fromJson(j['kurang'] as Map<String, dynamic>),
      );

  /// Ambil statistik berdasarkan kunci rating: sangat_baik | baik | kurang.
  RatingStat byKey(String key) {
    switch (key) {
      case 'sangat_baik':
        return sangatBaik;
      case 'baik':
        return baik;
      default:
        return kurang;
    }
  }
}

class Dashboard {
  final int total;
  final int menunggu;
  final int diproses;
  final int selesai;
  final int ditolak;
  final int lewatBatas;

  Dashboard({
    required this.total,
    required this.menunggu,
    required this.diproses,
    required this.selesai,
    required this.ditolak,
    required this.lewatBatas,
  });

  factory Dashboard.fromJson(Map<String, dynamic> j) => Dashboard(
        total: _toInt(j['total']),
        menunggu: _toInt(j['menunggu']),
        diproses: _toInt(j['diproses']),
        selesai: _toInt(j['selesai']),
        ditolak: _toInt(j['ditolak']),
        lewatBatas: _toInt(j['lewat_batas']),
      );
}

/// Satu ulasan survei (dilihat oleh Fakultas).
class ReviewItem {
  final String rating; // sangat_baik | baik | kurang
  final String? keterangan;
  final String kode;
  final String judul;
  final String pelaporNama;
  final String pelaporRole;
  final DateTime createdAt;

  ReviewItem({
    required this.rating,
    required this.keterangan,
    required this.kode,
    required this.judul,
    required this.pelaporNama,
    required this.pelaporRole,
    required this.createdAt,
  });

  factory ReviewItem.fromJson(Map<String, dynamic> j) => ReviewItem(
        rating: j['rating'] as String,
        keterangan: j['keterangan'] as String?,
        kode: j['kode'] as String,
        judul: j['judul'] as String,
        pelaporNama: j['pelapor_nama'] as String,
        pelaporRole: j['pelapor_role'] as String,
        createdAt: DateTime.parse(j['created_at'] as String).toLocal(),
      );
}
