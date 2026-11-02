-- ============================================================
-- Database: Aplikasi Pengaduan Fasilitas Rusak Fakultas
-- DBMS    : MySQL 8 / MariaDB 10.4+ (XAMPP, phpMyAdmin)
-- Cara pakai: buka phpMyAdmin > tab "Import" > pilih file ini,
--             atau: mysql -u root -p < schema.sql
-- ============================================================

CREATE DATABASE IF NOT EXISTS pengaduan_fasilitas
  CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE pengaduan_fasilitas;

-- ------------------------------------------------------------
-- 1. users : akun semua role (mahasiswa, dosen, fakultas)
--    Login: mahasiswa = nomor_induk (NIM), dosen = nomor_induk (NIDN 10 digit),
--           fakultas  = email. Mahasiswa/dosen dikelola oleh Fakultas.
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS users (
  id            INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  nama          VARCHAR(100) NOT NULL,
  email         VARCHAR(120) NOT NULL UNIQUE,
  password_hash VARCHAR(255) NOT NULL,
  role          ENUM('mahasiswa','dosen','fakultas') NOT NULL,
  nomor_induk   VARCHAR(30) NULL UNIQUE COMMENT 'NIM (mahasiswa) / NIDN (dosen) / ID staf (fakultas) - dipakai untuk login',
  alamat        VARCHAR(200) NULL,
  created_at    DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_users_role (role)
) ENGINE=InnoDB;

-- ------------------------------------------------------------
-- 2. complaints : pengaduan + kode unik pelacakan + batas 1 hari
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS complaints (
  id               INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  kode             VARCHAR(20) NOT NULL UNIQUE COMMENT 'contoh: ADU-261027-JZNEC',
  user_id          INT UNSIGNED NOT NULL,
  judul            VARCHAR(120) NOT NULL,
  lokasi           VARCHAR(150) NOT NULL,
  deskripsi        TEXT NOT NULL,
  status           ENUM('menunggu','diproses','selesai','ditolak') NOT NULL DEFAULT 'menunggu',
  catatan_fakultas TEXT NULL,
  created_at       DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  batas_waktu      DATETIME NOT NULL COMMENT 'created_at + 1 hari',
  updated_at       DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT fk_complaints_user FOREIGN KEY (user_id) REFERENCES users(id),
  INDEX idx_complaints_user (user_id),
  INDEX idx_complaints_status (status),
  INDEX idx_complaints_batas (batas_waktu)
) ENGINE=InnoDB;

-- ------------------------------------------------------------
-- 3. complaint_logs : riwayat perubahan status (timeline pelacakan)
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS complaint_logs (
  id           INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  complaint_id INT UNSIGNED NOT NULL,
  status       ENUM('menunggu','diproses','selesai','ditolak') NOT NULL,
  catatan      TEXT NULL,
  created_at   DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_logs_complaint FOREIGN KEY (complaint_id) REFERENCES complaints(id) ON DELETE CASCADE,
  INDEX idx_logs_complaint (complaint_id)
) ENGINE=InnoDB;

-- ------------------------------------------------------------
-- 3b. complaint_photos : foto lampiran pengaduan (maks. 3 per pengaduan,
--     file disimpan di folder backend/uploads/, kolom filename = nama file)
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS complaint_photos (
  id           INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  complaint_id INT UNSIGNED NOT NULL,
  filename     VARCHAR(100) NOT NULL,
  mime         VARCHAR(30) NOT NULL,
  created_at   DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_photos_complaint FOREIGN KEY (complaint_id) REFERENCES complaints(id) ON DELETE CASCADE,
  INDEX idx_photos_complaint (complaint_id)
) ENGINE=InnoDB;

-- ------------------------------------------------------------
-- 4. surveys : survei kepuasan (1 survei per pengaduan)
--    rating     : sangat_baik / baik / kurang
--    keterangan : opsional (boleh NULL)
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS surveys (
  id           INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  complaint_id INT UNSIGNED NOT NULL UNIQUE,
  user_id      INT UNSIGNED NOT NULL,
  rating       ENUM('sangat_baik','baik','kurang') NOT NULL,
  keterangan   VARCHAR(500) NULL,
  created_at   DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_surveys_complaint FOREIGN KEY (complaint_id) REFERENCES complaints(id) ON DELETE CASCADE,
  CONSTRAINT fk_surveys_user FOREIGN KEY (user_id) REFERENCES users(id),
  INDEX idx_surveys_rating (rating)
) ENGINE=InnoDB;

-- ------------------------------------------------------------
-- View: statistik grafik lingkaran (jumlah + persen per rating)
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW v_survey_stats AS
SELECT
  r.rating,
  COALESCE(s.jumlah, 0) AS jumlah,
  ROUND(COALESCE(s.jumlah, 0) * 100 / NULLIF(t.total, 0), 1) AS persen
FROM (SELECT 'sangat_baik' AS rating UNION ALL SELECT 'baik' UNION ALL SELECT 'kurang') r
LEFT JOIN (SELECT rating, COUNT(*) AS jumlah FROM surveys GROUP BY rating) s ON s.rating = r.rating
CROSS JOIN (SELECT COUNT(*) AS total FROM surveys) t;

-- View: Beranda (pengaduan berjalan) & Riwayat fakultas (selesai/ditolak >= 24 jam)
CREATE OR REPLACE VIEW v_pengaduan_beranda AS
SELECT * FROM complaints WHERE status IN ('menunggu','diproses');

CREATE OR REPLACE VIEW v_pengaduan_riwayat AS
SELECT * FROM complaints
WHERE status IN ('selesai','ditolak') AND updated_at <= NOW() - INTERVAL 24 HOUR;

-- View: pengaduan yang lewat batas 1 hari dan belum selesai
CREATE OR REPLACE VIEW v_pengaduan_lewat_batas AS
SELECT * FROM complaints
WHERE status IN ('menunggu','diproses') AND batas_waktu < NOW();

-- ------------------------------------------------------------
-- Data awal
--  Fakultas  : admin@fakultas.ac.id / admin123          (ganti setelah login pertama!)
--  Mahasiswa : 4 akun, login NIM + sandi awal "coba1234"
--  Dosen     : 4 akun, login NIDN + sandi awal "dosen123"
-- Hash berformat scrypt "salt:hash" sesuai backend Node.js di folder backend/.
-- Data mahasiswa/dosen di bawah hanya CONTOH; ganti/tambah lewat menu "Akun" di aplikasi.
-- ------------------------------------------------------------
INSERT INTO users (nama, email, password_hash, role, nomor_induk, alamat)
VALUES ('Admin Fakultas Teknik', 'admin@fakultas.ac.id',
        '3aecc2e3c8c487f3186b175765e0a9e0:77a0b212f493281f6dd48eaddf8ba9042950bed91d446d5ea652d1faf0a72eec30f34f0ca342b4466e79f3339cc66a5212e2a8166258d399adb21242571878ac',
        'fakultas', 'FAK-001', 'Gedung Dekanat Fakultas Teknik')
ON DUPLICATE KEY UPDATE nama = nama;

INSERT INTO users (nama, email, password_hash, role, nomor_induk, alamat) VALUES
  ('Kukuh Dwi Nur Cahyo', 'kukuhdwinurcahyo@gmail.com', '5ff3e2b890d898735bba15a2f73318c0:971fbffd5661ab04aa89910a09e80db25464f3146e7d011e3a8cd7cdd77f7169fca77775adadea221884546a7dcf1e311f5210d2ab80b3832284fb0a8f18574e', 'mahasiswa', '2024520018', 'Trenggalek'),
  ('Habibullah Sukron', 'sihabib16@gmail.com', 'bfbf0d88abfce45adb686ac11501965a:44171ad97d5365af6a1971735160b504c8656014dbf481940ff177204fb6e01a8df7f1d730102cfd956e99676d89dcff61d3014554561875628f32c33964972c', 'mahasiswa', '2024520051', 'Jl. Darma Pamekasan'),
  ('Mohammad Rizki Hoirur Roofi', 'rizki.hoirur@gmail.com', '475d9b8c86afdd1c19ae0d5669ed6474:8ff8b2841c57b3856368c0c8b2197216736621df4c140340d7be5e46cc7f296cc18fb3ee692f7fd4ca8d0e45c668f5b34b969dae85f59e032e0b476ea5efb0e9', 'mahasiswa', '2024520037', 'Pamekasan'),
  ('Muhammad Nabil Zamzami', 'nabil.zamzami@gmail.com', '8f1a66d406c0adbe69451656c38d0701:a7fa46dd155dd2100669ee60b6570da3e634cf00ed7c114abdcfcbd5099c5ce0373fd2281b87dd21c0e17bed09a417769fefcac19f6edc3b879a4e7efe0da903', 'mahasiswa', '2024520022', 'Pamekasan'),
  ('Sholeh Rachmatullah, S.Kom., M.Kom.', 'sholeh@unira.ac.id', '9fc97026a5748b0545b1e10c5751ba5f:25e80d578090f63a512bc987e8b597020abf8b48e9be5b2265571f0bede11fca6d8ad81218b20cec52f5a72b465f379f7c119d9a9ba88cccee93e7f3f23f6a04', 'dosen', '7104313441', 'Jl Raya Nyalaran 199 Pamekasan'),
  ('Jamilatul Badriyah, S.Kom., M.Tr.Kom.', 'mila@unira.ac.id', '7b1a13bd0b26b3ab8fb3c4bfd0d36146:5742283545bc11db94b1661c6028f412ac9dc8fc4744c0055a6b99f11d355dbd9c19c738da82a9076a7f92ee13f375ec8c411c41264408255d811a666db07b63', 'dosen', '7104313620', 'Bulu, Larangan Luar, Larangan Pamekasan'),
  ('Abd Wahab Syahroni, S.Kom., M.Kom.', 'roney@unira.ac.id', 'a63c48d6bbd8ac6b99f0e3c35a775b21:b4c8e1e7fd58e664079f6205256d90e4fee973c70dbf467f2b41c37663d930b587f5bbd61b4071e6aa790317a2062205814250cbd01b3fa20d8317568e6bd951', 'dosen', '7104313526', 'Galis Pamekasan'),
  ('Mohammad Nazir Arifin, M.Kom.', 'nazir@unira.ac.id', '3baab24ab9a4d71a92d8b83cbef69232:0b5c5408e5241d2f28d26bfe7b35fa1e9a17e7d46e9f123e7af0422422cc79860d9e2d52d3c06c65a601bc835f30979e2e45b15882fdb7e035fed82df1b8f987', 'dosen', '5116201014', 'Jl. Dirgahayu Gg. Kelurahan No. 5 Pamekasan')
ON DUPLICATE KEY UPDATE nama = nama;

-- ------------------------------------------------------------
-- Aturan bisnis (diterapkan di API, bukan di SQL):
--  * batas_waktu = created_at + 24 jam
--  * survei boleh diisi jika status 'selesai'/'ditolak' ATAU
--    NOW() > batas_waktu (walau pengaduan belum ditangani)
--  * hanya pelapor yang boleh mengisi survei, satu kali per pengaduan
--  * lupa sandi: Fakultas mereset sandi mahasiswa/dosen lewat aplikasi (menu Akun)
-- ------------------------------------------------------------
