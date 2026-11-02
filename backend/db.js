// Database SQLite memakai modul bawaan Node.js (node:sqlite), tanpa install paket.
const path = require('node:path');
const crypto = require('node:crypto');
const { DatabaseSync } = require('node:sqlite');

const DB_PATH = process.env.DB_PATH || path.join(__dirname, 'pengaduan.db');
const db = new DatabaseSync(DB_PATH);

db.exec(`
PRAGMA foreign_keys = ON;

CREATE TABLE IF NOT EXISTS users (
  id            INTEGER PRIMARY KEY AUTOINCREMENT,
  nama          TEXT NOT NULL,
  email         TEXT NOT NULL UNIQUE,
  password_hash TEXT NOT NULL,
  role          TEXT NOT NULL CHECK (role IN ('mahasiswa','dosen','fakultas')),
  nomor_induk   TEXT,            -- NIM (mahasiswa) / NIDN (dosen) / ID staf (fakultas)
  alamat        TEXT,
  created_at    TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS complaints (
  id               INTEGER PRIMARY KEY AUTOINCREMENT,
  kode             TEXT NOT NULL UNIQUE,
  user_id          INTEGER NOT NULL REFERENCES users(id),
  judul            TEXT NOT NULL,
  lokasi           TEXT NOT NULL,
  deskripsi        TEXT NOT NULL,
  status           TEXT NOT NULL DEFAULT 'menunggu'
                   CHECK (status IN ('menunggu','diproses','selesai','ditolak')),
  catatan_fakultas TEXT,
  created_at       TEXT NOT NULL,
  batas_waktu      TEXT NOT NULL,
  updated_at       TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS complaint_logs (
  id           INTEGER PRIMARY KEY AUTOINCREMENT,
  complaint_id INTEGER NOT NULL REFERENCES complaints(id),
  status       TEXT NOT NULL,
  catatan      TEXT,
  created_at   TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS complaint_photos (
  id           INTEGER PRIMARY KEY AUTOINCREMENT,
  complaint_id INTEGER NOT NULL REFERENCES complaints(id),
  filename     TEXT NOT NULL,   -- nama file di folder uploads/
  mime         TEXT NOT NULL,
  created_at   TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS surveys (
  id           INTEGER PRIMARY KEY AUTOINCREMENT,
  complaint_id INTEGER NOT NULL UNIQUE REFERENCES complaints(id),
  user_id      INTEGER NOT NULL REFERENCES users(id),
  rating       TEXT NOT NULL CHECK (rating IN ('sangat_baik','baik','kurang')),
  keterangan   TEXT,
  created_at   TEXT NOT NULL
);
`);

// ---------- Migrasi database lama (dibuat sebelum kolom alamat ada) ----------
if (!db.prepare('PRAGMA table_info(users)').all().some((k) => k.name === 'alamat')) {
  db.exec('ALTER TABLE users ADD COLUMN alamat TEXT');
}
// NIM / NIDN dipakai untuk login, jadi tidak boleh kembar.
try {
  db.exec(`CREATE UNIQUE INDEX IF NOT EXISTS idx_users_nomor_induk
           ON users(nomor_induk) WHERE nomor_induk IS NOT NULL`);
} catch (e) {
  console.warn('[db] Gagal membuat indeks unik nomor_induk (ada NIM/NIDN ganda di data lama):', e.message);
}

// ---------- Password (scrypt) ----------
function hashPassword(password) {
  const salt = crypto.randomBytes(16).toString('hex');
  const hash = crypto.scryptSync(password, salt, 64).toString('hex');
  return `${salt}:${hash}`;
}

function verifyPassword(password, stored) {
  const [salt, hash] = stored.split(':');
  const test = crypto.scryptSync(password, salt, 64);
  const orig = Buffer.from(hash, 'hex');
  return orig.length === test.length && crypto.timingSafeEqual(orig, test);
}

// ---------- Data awal (seed) ----------
// Akun fakultas dibuat di sini. Akun mahasiswa & dosen dikelola oleh Fakultas
// lewat menu "Akun" di aplikasi; 4 mahasiswa + 4 dosen contoh di bawah dimasukkan
// otomatis HANYA jika tabel users belum punya mahasiswa/dosen sama sekali.
const PASSWORD_AWAL_MAHASISWA = 'mahasiswa123';
const PASSWORD_AWAL_DOSEN = 'dosen123';

const MAHASISWA_CONTOH = [
  { nama: 'Kukuh Dwi Nur Cahyo',            nim: '2024520018', email: 'kukuhdwinurcahyo@gmail.com', alamat: 'Trenggalek',        password: 'coba1234' },
  { nama: 'Habibullah Sukron',              nim: '2024520051', email: 'sihabib16@gmail.com',        alamat: 'Jl. Darma Pamekasan', password: 'coba1234' },
  // Mahasiswa ke-3 dan ke-4: email/alamat (dan NIM Nabil) adalah isian sementara, ubah lewat menu Akun.
  { nama: 'Mohammad Rizki Hoirur Roofi',    nim: '2024520037', email: 'rizki.hoirur@gmail.com',     alamat: 'Pamekasan',         password: 'coba1234' },
  { nama: 'Muhammad Nabil Zamzami',         nim: '2024520022', email: 'nabil.zamzami@gmail.com',    alamat: 'Pamekasan',         password: 'coba1234' },
];

const DOSEN_CONTOH = [
  { nama: 'Sholeh Rachmatullah, S.Kom., M.Kom.',   nidn: '7104313441', email: 'sholeh@unira.ac.id', alamat: 'Jl Raya Nyalaran 199 Pamekasan', telepon: '081939356677' },
  { nama: 'Jamilatul Badriyah, S.Kom., M.Tr.Kom.', nidn: '7104313620', email: 'mila@unira.ac.id',   alamat: 'Bulu, Larangan Luar, Larangan Pamekasan', telepon: '081939775649' },
  { nama: 'Abd Wahab Syahroni, S.Kom., M.Kom.',    nidn: '7104313526', email: 'roney@unira.ac.id',  alamat: 'Galis Pamekasan', telepon: '082330511716' },
  { nama: 'Mohammad Nazir Arifin, M.Kom.',         nidn: '5116201014', email: 'nazir@unira.ac.id',  alamat: 'Jl. Dirgahayu Gg. Kelurahan No. 5 Pamekasan', telepon: '081515501708' },
];

function insertUser({ nama, email, password, role, nomor_induk, alamat }) {
  db.prepare(
    `INSERT INTO users (nama, email, password_hash, role, nomor_induk, alamat, created_at)
     VALUES (?, ?, ?, ?, ?, ?, ?)`
  ).run(nama, email.toLowerCase(), hashPassword(password), role, nomor_induk, alamat || null, new Date().toISOString());
}

function seedFakultas() {
  const email = (process.env.FAKULTAS_EMAIL || 'admin@fakultas.ac.id').toLowerCase();
  const password = process.env.FAKULTAS_PASSWORD || 'admin123';
  const ada = db.prepare('SELECT id FROM users WHERE email = ?').get(email);
  if (!ada) {
    insertUser({ nama: 'Admin Fakultas Teknik', email, password, role: 'fakultas', nomor_induk: 'FAK-001', alamat: 'Gedung Dekanat Fakultas Teknik' });
    console.log(`[seed] Akun fakultas dibuat: ${email} / ${password}`);
  }
}

function seedMahasiswaDosen() {
  const n = db.prepare(`SELECT COUNT(*) AS n FROM users WHERE role IN ('mahasiswa','dosen')`).get().n;
  if (n > 0) return;
  for (const m of MAHASISWA_CONTOH)
    insertUser({ nama: m.nama, email: m.email, password: m.password || PASSWORD_AWAL_MAHASISWA, role: 'mahasiswa', nomor_induk: m.nim, alamat: m.alamat });
  for (const d of DOSEN_CONTOH)
    insertUser({ nama: d.nama, email: d.email, password: PASSWORD_AWAL_DOSEN, role: 'dosen', nomor_induk: d.nidn, alamat: d.alamat });
  console.log(`[seed] ${MAHASISWA_CONTOH.length} mahasiswa (sandi awal "coba1234") dan ${DOSEN_CONTOH.length} dosen (sandi "${PASSWORD_AWAL_DOSEN}") dibuat.`);
}

seedFakultas();
seedMahasiswaDosen();

module.exports = { db, hashPassword, verifyPassword, MAHASISWA_CONTOH, DOSEN_CONTOH, PASSWORD_AWAL_MAHASISWA, PASSWORD_AWAL_DOSEN };
