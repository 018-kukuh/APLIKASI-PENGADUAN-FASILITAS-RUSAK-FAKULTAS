# Aplikasi Pengaduan Fasilitas Rusak Fakultas

Aplikasi mobile (Flutter) + REST API (Node.js) + database, untuk **Fakultas Teknik**.

| Role | 4 fitur |
|---|---|
| **Mahasiswa & Dosen** | 0. **Beranda** semua laporan berjalan (milik siapa pun, untuk cek laporan yang sama + lihat statusnya) · 1. Buat pengaduan (dapat **kode unik**, bisa **lampirkan foto**) · 2. Riwayat pengaduan · 3. Survei kepuasan + **grafik lingkaran live** |
| **Fakultas** | 0. **Beranda** info laporan masuk yang berjalan · 1. Dashboard + grafik live · 2. Kelola pengaduan (per status + **Riwayat**) · 3. **Lacak via kode (hanya Fakultas)** · 4. Ulasan survei · 5. **Kelola akun** mahasiswa & dosen (tambah, ubah data, **reset sandi lupa**) |

Cara login

| Role | Username | Password |
|---|---|---|
| Mahasiswa | **NIM** | sandi akun |
| Dosen | **NIDN** (10 digit) | sandi akun |
| Fakultas | **Email** | sandi akun |

Tidak ada pendaftaran mandiri: akun mahasiswa & dosen dibuat/dikelola oleh pihak Fakultas (menu **Akun**).

Aturan utama
- Semua role **wajib login** (JWT). Semua endpoint selain login/daftar menolak akses tanpa token.
- Batas penanganan pengaduan **1 hari** sejak dibuat.
- Survei kepuasan boleh diisi setelah pengaduan selesai/ditolak **atau** setelah lewat 1 hari walau belum ditangani.
- Pilihan survei: **Sangat Baik / Baik / Kurang**, keterangan **opsional**. Satu survei per pengaduan, hanya pelapor.
- **Beranda** (semua role): menampilkan laporan yang masih *Menunggu/Diproses* dari seluruh mahasiswa & dosen (nama pelapor hanya terlihat Fakultas). Laporan **hilang dari beranda** begitu berstatus *Selesai* atau *Ditolak*.
- **Pengaduan (Fakultas)**: dipisah per status (Menunggu, Diproses, Selesai, Ditolak). Yang *Selesai/Ditolak* tetap di tab statusnya selama **24 jam**, lalu otomatis pindah ke tab **Riwayat** (tersimpan terus, tidak dihapus). (Untuk demo cepat: `ARSIP_MS=60000 node server.js` = 1 menit.)
- **Foto pengaduan** (Mahasiswa & Dosen): opsional, maksimal **3 foto**, tiap foto maks. **5 MB**, format JPG/PNG/WEBP. Disimpan di `backend/uploads/` dan hanya bisa diambil dengan token login.
- Grafik lingkaran 3 bagian + persen, diperbarui otomatis tiap 5 detik.

```
APLIKASI-PENGADUAN-FASILITAS-RUSAK-FAKULTAS/
├── README.md
├── docs/
│   ├── Laporan-Kelompok-XX-Pengaduan-Fasilitas.docx
│   └── tautan-video-pengujian.md
├── backend/              API Node.js (server.js, db.js, test.js; foto tersimpan di uploads/)
│   └── database/         schema.sql (skema MySQL)
└── frontend/
    ├── web/              Flutter Web (jalankan di Chrome)
    └── mobile/           Flutter Mobile (Android / iOS)
```

---

## LANGKAH 1 — Jalankan backend (API)

Butuh **Node.js 22.13 atau lebih baru** (cek: `node -v`). Tidak perlu `npm install`.

```bash
cd backend
node test.js        # opsional: tes otomatis, harus tertulis "Semua 67 tes lulus."
node server.js      # API hidup di http://localhost:3000
```

Cek di browser: <http://localhost:3000/api/health> harus menampilkan `{"ok":true,...}`.

Database SQLite (`backend/pengaduan.db`) **dibuat otomatis** saat server pertama jalan, berikut data awal:

| Role | Login (username) | Password awal |
|---|---|---|
| Fakultas | `admin@fakultas.ac.id` | `admin123` |
| Mahasiswa (4 akun) | NIM `2024520018` (Kukuh Dwi Nur Cahyo), `2024520051` (Habibullah Sukron), `2024520037`, `2024520022` | `coba1234` |
| Dosen (4 akun) | NIDN `7104313441` (Sholeh), `7104313620` (Jamilatul Badriyah), `7104313526` (Abd Wahab Syahroni), `5116201014` (Mohammad Nazir Arifin) | `dosen123` |

Tiap akun mahasiswa/dosen menyimpan **nama, NIM/NIDN, gmail, dan alamat** (lihat daftar lengkap di menu **Akun** pada login Fakultas, atau di `backend/db.js` bagian `MAHASISWA_CONTOH` / `DOSEN_CONTOH`).
Data contoh ini **hanya contoh**: ganti dengan data asli lewat menu **Akun** (ubah data) atau edit daftar di `db.js` sebelum database pertama dibuat.

> Data contoh hanya dimasukkan jika database belum punya mahasiswa/dosen. Jika Anda sudah punya `pengaduan.db` lama dan ingin data contoh ini, hentikan server, hapus `backend/pengaduan.db`, lalu jalankan ulang (kolom `alamat` pada database lama ditambahkan otomatis).

### Lupa sandi / memperbarui data akun
Login sebagai **Fakultas** → tab **Akun** → pilih Mahasiswa/Dosen:
- **Ubah data**: nama, NIM/NIDN, gmail, alamat.
- **Reset sandi**: isi sandi baru, atau kosongkan agar dibuat otomatis (acak 8 karakter). Sandi ditampilkan sekali untuk diberikan ke yang bersangkutan; sesi login lama akun itu otomatis berakhir.
- **Tambah Mahasiswa/Dosen**: tombol di kanan bawah.

> Ingin ganti akun/secret? Jalankan dengan variabel:
> `FAKULTAS_EMAIL=... FAKULTAS_PASSWORD=... JWT_SECRET=... node server.js`
> (Windows PowerShell: `$env:JWT_SECRET="..."; node server.js`)

### Tentang `backend/database/schema.sql` (MySQL)
Backend ini memakai SQLite agar langsung jalan tanpa instalasi. `schema.sql` adalah skema yang **setara dalam MySQL/MariaDB** (XAMPP/phpMyAdmin), berguna untuk lampiran laporan/ERD atau jika dosen meminta MySQL. Untuk benar-benar memakai MySQL, kode `backend/db.js` perlu diganti ke driver MySQL.

---

## LANGKAH 2 — Siapkan proyek Flutter

Butuh Flutter SDK (cek: `flutter doctor`). Kode Dart (`lib/`) di `frontend/web` dan `frontend/mobile` sama; yang berbeda hanya folder platformnya.

```bash
cd frontend/web      # atau: cd frontend/mobile
flutter pub get
```
Paket yang dipakai: `http`, `provider`, `shared_preferences`, `intl`, `fl_chart`, `image_picker` (upload foto).

> iOS: izin galeri/kamera sudah ditambahkan di `frontend/mobile/ios/Runner/Info.plist`.

---

## LANGKAH 3 — Atur izin internet Android (hanya jika memakai Android)

Sudah dikerjakan di `frontend/mobile/android/app/src/main/AndroidManifest.xml` (izin INTERNET dan `usesCleartextTraffic`). Cukup dicek jika koneksi Android ditolak. Isinya:

1. Tambahkan **sebelum** tag `<application`:
   ```xml
   <uses-permission android:name="android.permission.INTERNET"/>
   ```
2. Pada tag `<application ...>` tambahkan atribut (karena API memakai `http`, bukan `https`):
   ```xml
   android:usesCleartextTraffic="true"
   ```

Pengguna Flutter Web tidak perlu langkah ini (CORS sudah dibuka di backend).

---

## LANGKAH 4 — Jalankan aplikasi

Pastikan backend (Langkah 1) **sedang berjalan**, lalu jalankan dari folder `frontend/web` (Chrome) atau `frontend/mobile` (Android/HP):

| Perangkat | Perintah | Alamat API otomatis |
|---|---|---|
| Chrome (web) | `flutter run -d chrome` | `http://localhost:3000` |
| Emulator Android | `flutter run` | `http://10.0.2.2:3000` |
| **HP asli** (satu Wi-Fi dengan laptop) | `flutter run --dart-define=API_URL=http://192.168.1.10:3000` | IP laptop Anda |

Cara tahu IP laptop: Windows `ipconfig` (IPv4 Address), Mac/Linux `ifconfig` / `ip a`.
Jika HP tidak bisa terhubung, izinkan port **3000** di firewall laptop.

---

## LANGKAH 5 — Uji alur lengkap (checklist)

> **Tiga tautan login terpisah** (tidak saling terhubung): `http://localhost:PORT/#/mahasiswa`, `http://localhost:PORT/#/dosen`, `http://localhost:PORT/#/fakultas`. Tanpa `#/...` = login Mahasiswa. Setelah mengganti bagian `#/...` di alamat, tekan **F5**.

1. Buka tautan login **Mahasiswa** (`.../#/mahasiswa`): NIM `2024520018` / sandi `coba1234`. Dosen memakai tautan sendiri (`.../#/dosen`): NIDN `7104313441` / `dosen123`.
2. Tab **Buat Pengaduan** → isi judul, lokasi, deskripsi → muncul **kode** (mis. `ADU-261028-K7M2Q`). Salin.
3. Buka tab **Beranda** → pengaduan tadi tampil (juga di Beranda dosen/mahasiswa lain); ketuk untuk melihat status & timeline. Fitur **Lacak** via kode hanya ada di login Fakultas.
4. Keluar, masuk lewat tautan login **Fakultas** (`.../#/fakultas`): `admin@fakultas.ac.id` / `admin123`.
5. **Kelola Pengaduan** → buka pengaduan → ubah status ke *Diproses*, lalu *Selesai* + catatan.
6. Masuk lagi sebagai mahasiswa (NIM) → tab **Survei** → pilih Sangat Baik/Baik/Kurang (keterangan boleh kosong) → Kirim.
7. Lihat **grafik lingkaran** bergerak sendiri; di sisi Fakultas muncul di **Dashboard** dan **Ulasan**.
8. Uji lupa sandi: login Fakultas → tab **Akun** → **Reset sandi** pada seorang mahasiswa → login dengan NIM tersebut memakai sandi baru.
9. Uji batas 1 hari: survei untuk pengaduan yang masih *Menunggu* baru bisa diisi setelah 24 jam.
   Untuk demo cepat, ubah `BATAS_PENGADUAN_MS` di `backend/server.js` menjadi `60 * 1000` (1 menit), restart server.

---

## Daftar endpoint API

| Method | Path | Role | Fungsi |
|---|---|---|---|
| POST | `/api/auth/login` | — | Login (kirim `identifier` = NIM/NIDN/email, `password`, `role`) |
| GET | `/api/users?role=&q=` | fakultas | Daftar akun mahasiswa/dosen (+ pencarian) |
| POST | `/api/users` | fakultas | Tambah akun mahasiswa/dosen |
| PATCH | `/api/users/:id` | fakultas | Ubah nama, NIM/NIDN, email, alamat |
| POST | `/api/users/:id/reset-password` | fakultas | Reset sandi (kosong = dibuat otomatis) |
| GET | `/api/auth/me` | semua | Profil dari token |
| POST | `/api/complaints` | mhs, dosen | Buat pengaduan → kode unik (+ `foto`: daftar base64, opsional, maks. 3) |
| GET | `/api/complaints/aktif` | semua | Beranda: semua pengaduan Menunggu/Diproses |
| GET | `/api/photos/:id` | semua | Gambar lampiran pengaduan |
| GET | `/api/complaints/mine` | mhs, dosen | Riwayat sendiri |
| GET | `/api/complaints/track/:kode` | semua (UI: Lacak hanya Fakultas; mhs/dosen lewat Beranda) | Lacak via kode + timeline |
| GET | `/api/complaints?status=` | fakultas | Pengaduan per status: `semua`, `menunggu`, `diproses`, `selesai`, `ditolak` (selesai/ditolak < 24 jam), `riwayat` (selesai/ditolak ≥ 24 jam) |
| PATCH | `/api/complaints/:id/status` | fakultas | Ubah status + catatan |
| POST | `/api/surveys` | mhs, dosen | Kirim survei |
| GET | `/api/surveys/stats` | semua | Data grafik (jumlah + persen) |
| GET | `/api/surveys` | fakultas | Daftar ulasan |
| GET | `/api/dashboard` | fakultas | Ringkasan angka |

## Masalah umum

| Gejala | Penyebab / solusi |
|---|---|
| "Tidak dapat terhubung ke server" | Backend belum jalan, atau alamat salah (lihat tabel Langkah 4). |
| Android: koneksi ditolak padahal server jalan | Langkah 3 belum dilakukan. |
| HP asli tidak bisa konek | Pakai `--dart-define=API_URL=http://IP_LAPTOP:3000`, satu Wi-Fi, buka port 3000. |
| "NIM/NIDN atau password salah" | Dropdown "Masuk sebagai" harus sesuai role (NIM untuk Mahasiswa, NIDN untuk Dosen). Lupa sandi → minta Fakultas reset. |
| `node:sqlite` tidak ditemukan | Node terlalu lama; pakai Node 22.13+. |
| Ingin reset data | Hentikan server, hapus `backend/pengaduan.db`, jalankan ulang. |
