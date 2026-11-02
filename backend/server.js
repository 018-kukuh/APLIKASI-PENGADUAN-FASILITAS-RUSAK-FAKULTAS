// REST API Aplikasi Pengaduan Fasilitas Rusak Fakultas
// Tanpa dependensi eksternal: hanya modul bawaan Node.js (>= 22.13).
const http = require('node:http');
const crypto = require('node:crypto');
const fs = require('node:fs');
const path = require('node:path');
const { db, hashPassword, verifyPassword } = require('./db');

const PORT = Number(process.env.PORT || 3000);
const JWT_SECRET = process.env.JWT_SECRET || 'ganti-secret-ini-di-produksi';
const TOKEN_TTL_SEC = 60 * 60 * 24 * 7; // 7 hari
const BATAS_PENGADUAN_MS = 24 * 60 * 60 * 1000; // batas maksimal penanganan: 1 hari

// Pengaduan yang sudah selesai/ditolak tetap tampil di daftar status selama 24 jam,
// setelah itu otomatis pindah ke Riwayat (bagian Pengaduan role Fakultas).
const ARSIP_MS = Number(process.env.ARSIP_MS || 24 * 60 * 60 * 1000);

// Foto pengaduan (dikirim base64 lewat JSON, disimpan sebagai file di folder uploads/)
const UPLOAD_DIR = process.env.UPLOAD_DIR || path.join(__dirname, 'uploads');
const MAX_FOTO = 3;
const MAX_FOTO_BYTES = 5 * 1024 * 1024;
const MAX_BODY_FOTO = 25 * 1024 * 1024; // body JSON untuk POST /api/complaints (3 foto base64)
fs.mkdirSync(UPLOAD_DIR, { recursive: true });

const STATUS_VALID = ['menunggu', 'diproses', 'selesai', 'ditolak'];
const RATING_VALID = ['sangat_baik', 'baik', 'kurang'];

// ---------------------------------------------------------------- JWT (HS256)
const b64u = (x) => Buffer.from(x).toString('base64url');

function signToken(payload) {
  const header = b64u(JSON.stringify({ alg: 'HS256', typ: 'JWT' }));
  const body = b64u(JSON.stringify({ ...payload, exp: Math.floor(Date.now() / 1000) + TOKEN_TTL_SEC }));
  const sig = crypto.createHmac('sha256', JWT_SECRET).update(`${header}.${body}`).digest('base64url');
  return `${header}.${body}.${sig}`;
}

function verifyToken(token) {
  const parts = (token || '').split('.');
  if (parts.length !== 3) return null;
  const [header, body, sig] = parts;
  const expected = crypto.createHmac('sha256', JWT_SECRET).update(`${header}.${body}`).digest('base64url');
  const a = Buffer.from(sig);
  const b = Buffer.from(expected);
  if (a.length !== b.length || !crypto.timingSafeEqual(a, b)) return null;
  try {
    const payload = JSON.parse(Buffer.from(body, 'base64url').toString());
    if (payload.exp < Math.floor(Date.now() / 1000)) return null;
    return payload;
  } catch {
    return null;
  }
}

// ---------------------------------------------------------------- Helper
class HttpError extends Error {
  constructor(status, message) {
    super(message);
    this.status = status;
  }
}

function send(res, status, data) {
  const body = JSON.stringify(data);
  res.writeHead(status, {
    'Content-Type': 'application/json; charset=utf-8',
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'Content-Type, Authorization',
    'Access-Control-Allow-Methods': 'GET, POST, PATCH, DELETE, OPTIONS',
  });
  res.end(body);
}

function readJson(req, limit = 1_000_000) {
  return new Promise((resolve, reject) => {
    let raw = '';
    let tooBig = false;
    req.on('data', (c) => {
      if (tooBig) return;
      raw += c;
      if (raw.length > limit) {
        tooBig = true;
        raw = '';
        reject(new HttpError(413, 'Ukuran data/foto terlalu besar'));
      }
    });
    req.on('end', () => {
      if (tooBig) return;
      if (!raw) return resolve({});
      try {
        resolve(JSON.parse(raw));
      } catch {
        reject(new HttpError(400, 'Body harus berupa JSON yang valid'));
      }
    });
    req.on('error', reject);
  });
}

const str = (v) => (typeof v === 'string' ? v.trim() : '');

function publicUser(u) {
  return {
    id: u.id,
    nama: u.nama,
    email: u.email,
    role: u.role,
    nomor_induk: u.nomor_induk,
    alamat: u.alamat || null,
  };
}

// Sidik jari singkat dari hash password: token lama otomatis tidak berlaku
// setelah password diganti / di-reset oleh Fakultas.
const pwStamp = (u) => crypto.createHash('sha256').update(u.password_hash).digest('hex').slice(0, 16);
const tokenFor = (u) => signToken({ sub: u.id, role: u.role, pv: pwStamp(u) });

const ID_LABEL = { mahasiswa: 'NIM', dosen: 'NIDN', fakultas: 'Email' };

function generatePassword(len = 8) {
  // Tanpa karakter yang mirip (0/O, 1/l/I) supaya mudah dibaca & diketik.
  const alfabet = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnpqrstuvwxyz23456789';
  let out = '';
  for (const byte of crypto.randomBytes(len)) out += alfabet[byte % alfabet.length];
  return out;
}

function makeKode() {
  // Tanpa karakter yang mirip (0/O, 1/I) supaya mudah diketik.
  const alfabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  const d = new Date();
  const tgl =
    String(d.getFullYear()).slice(2) +
    String(d.getMonth() + 1).padStart(2, '0') +
    String(d.getDate()).padStart(2, '0');
  for (let i = 0; i < 10; i++) {
    let acak = '';
    for (const byte of crypto.randomBytes(5)) acak += alfabet[byte % alfabet.length];
    const kode = `ADU-${tgl}-${acak}`;
    if (!db.prepare('SELECT 1 FROM complaints WHERE kode = ?').get(kode)) return kode;
  }
  throw new HttpError(500, 'Gagal membuat kode unik');
}

// Bentuk respons pengaduan, termasuk status batas waktu & kelayakan survei.
function serializeComplaint(c, { withPelapor = false } = {}) {
  const now = Date.now();
  const lewatBatas = now > new Date(c.batas_waktu).getTime();
  const final = c.status === 'selesai' || c.status === 'ditolak';
  const sudahSurvei = !!db.prepare('SELECT 1 FROM surveys WHERE complaint_id = ?').get(c.id);
  const fotos = db.prepare('SELECT id FROM complaint_photos WHERE complaint_id = ? ORDER BY id').all(c.id);
  const out = {
    id: c.id,
    kode: c.kode,
    judul: c.judul,
    lokasi: c.lokasi,
    deskripsi: c.deskripsi,
    status: c.status,
    catatan_fakultas: c.catatan_fakultas,
    created_at: c.created_at,
    updated_at: c.updated_at,
    batas_waktu: c.batas_waktu,
    lewat_batas: lewatBatas && !final,
    sudah_survei: sudahSurvei,
    // Survei boleh diisi jika sudah selesai/ditolak ATAU batas 1 hari terlewati
    // (walau pengaduan belum ditangani).
    bisa_survei: !sudahSurvei && (final || lewatBatas),
    // Foto lampiran: ambil gambar lewat GET /api/photos/:id (butuh token).
    foto: fotos.map((f) => ({ id: f.id, url: `/api/photos/${f.id}` })),
    // Selesai/ditolak lebih dari 24 jam -> masuk Riwayat (tersimpan permanen, tidak dihapus) (Fakultas).
    diarsipkan: final && now - new Date(c.updated_at).getTime() >= ARSIP_MS,
  };
  if (withPelapor) {
    out.pelapor = { nama: c.pelapor_nama, role: c.pelapor_role, nomor_induk: c.pelapor_nomor_induk };
  }
  return out;
}

const COMPLAINT_WITH_USER = `
  SELECT c.*, u.nama AS pelapor_nama, u.role AS pelapor_role, u.nomor_induk AS pelapor_nomor_induk
  FROM complaints c JOIN users u ON u.id = c.user_id`;

function requireAuth(req, roles) {
  const h = req.headers['authorization'] || '';
  const token = h.startsWith('Bearer ') ? h.slice(7) : '';
  const payload = verifyToken(token);
  if (!payload) throw new HttpError(401, 'Silakan login terlebih dahulu');
  const user = db.prepare('SELECT * FROM users WHERE id = ?').get(payload.sub);
  if (!user) throw new HttpError(401, 'Akun tidak ditemukan');
  if (payload.pv !== pwStamp(user)) throw new HttpError(401, 'Sesi berakhir, silakan login kembali');
  if (roles && !roles.includes(user.role)) throw new HttpError(403, 'Akses ditolak untuk role Anda');
  return user;
}

function surveyStats() {
  const rows = db.prepare('SELECT rating, COUNT(*) AS n FROM surveys GROUP BY rating').all();
  const count = { sangat_baik: 0, baik: 0, kurang: 0 };
  for (const r of rows) count[r.rating] = r.n;
  const total = count.sangat_baik + count.baik + count.kurang;
  const persen = (n) => (total === 0 ? 0 : Math.round((n / total) * 1000) / 10);
  return {
    total,
    sangat_baik: { jumlah: count.sangat_baik, persen: persen(count.sangat_baik) },
    baik: { jumlah: count.baik, persen: persen(count.baik) },
    kurang: { jumlah: count.kurang, persen: persen(count.kurang) },
    updated_at: new Date().toISOString(),
  };
}

// ---------------------------------------------------------------- Foto
const MIME_EXT = { 'image/jpeg': 'jpg', 'image/png': 'png', 'image/webp': 'webp' };

function detectMime(buf) {
  if (buf.length > 12 && buf[0] === 0xff && buf[1] === 0xd8 && buf[2] === 0xff) return 'image/jpeg';
  if (buf.length > 12 && buf.subarray(0, 8).equals(Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a])))
    return 'image/png';
  if (buf.length > 12 && buf.subarray(0, 4).toString() === 'RIFF' && buf.subarray(8, 12).toString() === 'WEBP')
    return 'image/webp';
  return null;
}

// Validasi daftar foto dari body (base64). Mengembalikan [{ buf, mime }]; belum menulis apa pun ke disk.
function parseFotos(input) {
  if (input === undefined || input === null) return [];
  if (!Array.isArray(input)) throw new HttpError(400, 'Foto harus berupa daftar');
  if (input.length > MAX_FOTO) throw new HttpError(400, `Maksimal ${MAX_FOTO} foto per pengaduan`);
  return input.map((item, i) => {
    const raw = typeof item === 'string' ? item : item && typeof item.data === 'string' ? item.data : '';
    const b64 = raw.replace(/^data:[^;]+;base64,/, '');
    if (!b64) throw new HttpError(400, `Foto ke-${i + 1} kosong`);
    const buf = Buffer.from(b64, 'base64');
    if (buf.length > MAX_FOTO_BYTES) throw new HttpError(413, `Foto ke-${i + 1} lebih dari 5 MB`);
    const mime = detectMime(buf);
    if (!mime) throw new HttpError(400, `Foto ke-${i + 1} harus berformat JPG, PNG, atau WEBP`);
    return { buf, mime };
  });
}

// ---------------------------------------------------------------- Routes
// Tiap route: [method, pola path, handler(req, params, body) -> {status?, data}]
const routes = [];
const route = (method, pattern, optsOrHandler, maybeHandler) => {
  const opts = typeof optsOrHandler === 'function' ? {} : optsOrHandler;
  const handler = typeof optsOrHandler === 'function' ? optsOrHandler : maybeHandler;
  const keys = [];
  const regex = new RegExp('^' + pattern.replace(/:([a-zA-Z]+)/g, (_, k) => (keys.push(k), '([^/]+)')) + '/?$');
  routes.push({ method, regex, keys, handler, maxBody: opts.maxBody });
};

// ----- Auth
// Login:
//  - mahasiswa : NIM   + password
//  - dosen     : NIDN   + password
//  - fakultas  : email + password
// Akun mahasiswa/dosen dibuat & dikelola oleh Fakultas (tidak ada pendaftaran mandiri).
route('POST', '/api/auth/login', (req, p, body) => {
  const role = str(body.role);
  const identifier = str(body.identifier || body.email || body.nomor_induk);
  const password = typeof body.password === 'string' ? body.password : '';
  if (!['mahasiswa', 'dosen', 'fakultas'].includes(role)) throw new HttpError(400, 'Role tidak valid');
  if (!identifier || !password) throw new HttpError(400, `${ID_LABEL[role]} dan password wajib diisi`);

  const user =
    role === 'fakultas'
      ? db.prepare(`SELECT * FROM users WHERE email = ? AND role = 'fakultas'`).get(identifier.toLowerCase())
      : db.prepare('SELECT * FROM users WHERE nomor_induk = ? AND role = ?').get(identifier, role);
  if (!user || !verifyPassword(password, user.password_hash))
    throw new HttpError(401, `${ID_LABEL[role]} atau password salah`);
  return { data: { token: tokenFor(user), user: publicUser(user) } };
});

route('GET', '/api/auth/me', (req) => {
  const user = requireAuth(req);
  return { data: { user: publicUser(user) } };
});

// ----- Pengaduan (mahasiswa & dosen)
route('POST', '/api/complaints', { maxBody: MAX_BODY_FOTO }, (req, p, body) => {
  const user = requireAuth(req, ['mahasiswa', 'dosen']);
  const judul = str(body.judul);
  const lokasi = str(body.lokasi);
  const deskripsi = str(body.deskripsi);
  if (!judul || !lokasi || !deskripsi) throw new HttpError(400, 'Judul, lokasi, dan deskripsi wajib diisi');
  if (judul.length > 120) throw new HttpError(400, 'Judul maksimal 120 karakter');
  const fotos = parseFotos(body.foto); // foto bersifat opsional

  const now = new Date();
  const iso = now.toISOString();
  const batas = new Date(now.getTime() + BATAS_PENGADUAN_MS).toISOString();
  const kode = makeKode();
  const info = db
    .prepare(
      `INSERT INTO complaints (kode, user_id, judul, lokasi, deskripsi, status, created_at, batas_waktu, updated_at)
       VALUES (?, ?, ?, ?, ?, 'menunggu', ?, ?, ?)`
    )
    .run(kode, user.id, judul, lokasi, deskripsi, iso, batas, iso);
  const id = Number(info.lastInsertRowid);
  db.prepare('INSERT INTO complaint_logs (complaint_id, status, catatan, created_at) VALUES (?, ?, ?, ?)').run(
    id,
    'menunggu',
    'Pengaduan diterima',
    iso
  );
  for (const f of fotos) {
    const filename = `${crypto.randomBytes(16).toString('hex')}.${MIME_EXT[f.mime]}`;
    fs.writeFileSync(path.join(UPLOAD_DIR, filename), f.buf);
    db.prepare('INSERT INTO complaint_photos (complaint_id, filename, mime, created_at) VALUES (?, ?, ?, ?)').run(
      id,
      filename,
      f.mime,
      iso
    );
  }
  const c = db.prepare(`${COMPLAINT_WITH_USER} WHERE c.id = ?`).get(id);
  return { status: 201, data: { complaint: serializeComplaint(c) } };
});

route('GET', '/api/complaints/mine', (req) => {
  const user = requireAuth(req, ['mahasiswa', 'dosen']);
  const rows = db.prepare(`${COMPLAINT_WITH_USER} WHERE c.user_id = ? ORDER BY c.created_at DESC`).all(user.id);
  return { data: { complaints: rows.map((c) => serializeComplaint(c)) } };
});

// Beranda informasi laporan (semua role): semua pengaduan yang masih berjalan
// (Menunggu/Diproses) dari seluruh mahasiswa & dosen, supaya pelapor tahu jika
// sudah ada laporan yang sama. Nama pelapor hanya dikirim ke Fakultas.
// Pengaduan otomatis hilang dari beranda begitu berstatus selesai atau ditolak.
route('GET', '/api/complaints/aktif', (req) => {
  const user = requireAuth(req);
  const rows = db
    .prepare(`${COMPLAINT_WITH_USER} WHERE c.status IN ('menunggu','diproses') ORDER BY c.created_at DESC`)
    .all();
  const complaints = rows.map((c) => {
    const out = serializeComplaint(c, { withPelapor: user.role === 'fakultas' });
    out.milik_saya = c.user_id === user.id;
    if (!out.milik_saya) out.bisa_survei = false;
    return out;
  });
  return { data: { complaints } };
});

// Gambar lampiran pengaduan (semua role yang login, sama seperti fitur lacak kode).
route('GET', '/api/photos/:id', (req, p) => {
  requireAuth(req);
  const f = db.prepare('SELECT * FROM complaint_photos WHERE id = ?').get(Number(p.id));
  const file = f && path.join(UPLOAD_DIR, path.basename(f.filename));
  if (!f || !fs.existsSync(file)) throw new HttpError(404, 'Foto tidak ditemukan');
  return { raw: { mime: f.mime, buffer: fs.readFileSync(file) } };
});

// Lacak lewat kode unik (semua role yang sudah login)
route('GET', '/api/complaints/track/:kode', (req, p) => {
  const user = requireAuth(req);
  const kode = decodeURIComponent(p.kode).trim().toUpperCase();
  const c = db.prepare(`${COMPLAINT_WITH_USER} WHERE c.kode = ?`).get(kode);
  if (!c) throw new HttpError(404, 'Kode pengaduan tidak ditemukan');
  const logs = db
    .prepare('SELECT status, catatan, created_at FROM complaint_logs WHERE complaint_id = ? ORDER BY id ASC')
    .all(c.id);
  const data = serializeComplaint(c, { withPelapor: user.role === 'fakultas' });
  data.milik_saya = c.user_id === user.id;
  // Hanya pelapor yang boleh mengisi survei.
  if (c.user_id !== user.id) data.bisa_survei = false;
  return { data: { complaint: data, riwayat: logs } };
});

// ----- Fakultas
// Daftar pengaduan untuk Fakultas, dipisah menurut status:
//  - menunggu / diproses : semua yang berstatus itu
//  - selesai / ditolak   : hanya yang final < 24 jam (setelah itu pindah ke riwayat)
//  - semua               : seluruh pengaduan yang belum diarsipkan
//  - riwayat             : selesai/ditolak yang sudah lebih dari 24 jam (tanpa batas waktu, tidak pernah dihapus)
route('GET', '/api/complaints', (req) => {
  requireAuth(req, ['fakultas']);
  const url = new URL(req.url, 'http://x');
  const status = url.searchParams.get('status') || 'semua';
  if (status !== 'semua' && status !== 'riwayat' && !STATUS_VALID.includes(status))
    throw new HttpError(400, 'Status tidak valid');
  const batas = new Date(Date.now() - ARSIP_MS).toISOString();
  const belumArsip = `(c.status IN ('menunggu','diproses') OR c.updated_at > ?)`;
  let rows;
  if (status === 'riwayat') {
    rows = db
      .prepare(`${COMPLAINT_WITH_USER} WHERE c.status IN ('selesai','ditolak') AND c.updated_at <= ? ORDER BY c.updated_at DESC`)
      .all(batas);
  } else if (status === 'semua') {
    rows = db.prepare(`${COMPLAINT_WITH_USER} WHERE ${belumArsip} ORDER BY c.created_at DESC`).all(batas);
  } else {
    rows = db
      .prepare(`${COMPLAINT_WITH_USER} WHERE c.status = ? AND ${belumArsip} ORDER BY c.created_at DESC`)
      .all(status, batas);
  }
  return { data: { complaints: rows.map((c) => serializeComplaint(c, { withPelapor: true })) } };
});

route('PATCH', '/api/complaints/:id/status', (req, p, body) => {
  requireAuth(req, ['fakultas']);
  const status = str(body.status);
  const catatan = str(body.catatan);
  if (!STATUS_VALID.includes(status)) throw new HttpError(400, `Status harus salah satu: ${STATUS_VALID.join(', ')}`);
  const c = db.prepare('SELECT * FROM complaints WHERE id = ?').get(Number(p.id));
  if (!c) throw new HttpError(404, 'Pengaduan tidak ditemukan');
  const iso = new Date().toISOString();
  db.prepare('UPDATE complaints SET status = ?, catatan_fakultas = ?, updated_at = ? WHERE id = ?').run(
    status,
    catatan || c.catatan_fakultas,
    iso,
    c.id
  );
  db.prepare('INSERT INTO complaint_logs (complaint_id, status, catatan, created_at) VALUES (?, ?, ?, ?)').run(
    c.id,
    status,
    catatan || null,
    iso
  );
  const updated = db.prepare(`${COMPLAINT_WITH_USER} WHERE c.id = ?`).get(c.id);
  return { data: { complaint: serializeComplaint(updated, { withPelapor: true }) } };
});

route('GET', '/api/dashboard', (req) => {
  requireAuth(req, ['fakultas']);
  const per = db.prepare('SELECT status, COUNT(*) AS n FROM complaints GROUP BY status').all();
  const byStatus = { menunggu: 0, diproses: 0, selesai: 0, ditolak: 0 };
  for (const r of per) byStatus[r.status] = r.n;
  const total = Object.values(byStatus).reduce((a, b) => a + b, 0);
  const lewat = db
    .prepare(`SELECT COUNT(*) AS n FROM complaints WHERE status IN ('menunggu','diproses') AND batas_waktu < ?`)
    .get(new Date().toISOString()).n;
  return { data: { total, ...byStatus, lewat_batas: lewat, survei: surveyStats() } };
});

// ----- Survei kepuasan
route('POST', '/api/surveys', (req, p, body) => {
  const user = requireAuth(req, ['mahasiswa', 'dosen']);
  const rating = str(body.rating);
  const keterangan = str(body.keterangan); // opsional
  if (!RATING_VALID.includes(rating)) throw new HttpError(400, `Rating harus salah satu: ${RATING_VALID.join(', ')}`);
  if (keterangan.length > 500) throw new HttpError(400, 'Keterangan maksimal 500 karakter');

  let c;
  if (body.complaint_id) c = db.prepare('SELECT * FROM complaints WHERE id = ?').get(Number(body.complaint_id));
  else if (body.kode) c = db.prepare('SELECT * FROM complaints WHERE kode = ?').get(str(body.kode).toUpperCase());
  if (!c) throw new HttpError(404, 'Pengaduan tidak ditemukan');
  if (c.user_id !== user.id) throw new HttpError(403, 'Hanya pelapor yang dapat mengisi survei pengaduan ini');
  if (db.prepare('SELECT 1 FROM surveys WHERE complaint_id = ?').get(c.id))
    throw new HttpError(409, 'Survei untuk pengaduan ini sudah diisi');

  const final = c.status === 'selesai' || c.status === 'ditolak';
  const lewatBatas = Date.now() > new Date(c.batas_waktu).getTime();
  if (!final && !lewatBatas)
    throw new HttpError(422, 'Survei baru bisa diisi setelah pengaduan ditangani atau melewati batas waktu 1 hari');

  db.prepare('INSERT INTO surveys (complaint_id, user_id, rating, keterangan, created_at) VALUES (?, ?, ?, ?, ?)').run(
    c.id,
    user.id,
    rating,
    keterangan || null,
    new Date().toISOString()
  );
  return { status: 201, data: { message: 'Terima kasih, survei berhasil dikirim', stats: surveyStats() } };
});

// Statistik untuk grafik lingkaran live (semua role yang login)
route('GET', '/api/surveys/stats', (req) => {
  requireAuth(req);
  return { data: surveyStats() };
});

// Daftar ulasan (fakultas)
route('GET', '/api/surveys', (req) => {
  requireAuth(req, ['fakultas']);
  const rows = db
    .prepare(
      `SELECT s.id, s.rating, s.keterangan, s.created_at, c.kode, c.judul, u.nama AS pelapor_nama, u.role AS pelapor_role
       FROM surveys s
       JOIN complaints c ON c.id = s.complaint_id
       JOIN users u ON u.id = s.user_id
       ORDER BY s.created_at DESC`
    )
    .all();
  return { data: { surveys: rows } };
});

// ----- Kelola akun mahasiswa & dosen (khusus Fakultas)
const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

// Validasi & normalisasi field akun. Field yang tidak dikirim -> undefined (untuk PATCH).
function parseUserFields(body, role) {
  const out = {};
  if (body.nama !== undefined) {
    out.nama = str(body.nama);
    if (!out.nama) throw new HttpError(400, 'Nama wajib diisi');
    if (out.nama.length > 100) throw new HttpError(400, 'Nama maksimal 100 karakter');
  }
  if (body.nomor_induk !== undefined) {
    out.nomor_induk = str(body.nomor_induk);
    if (role === 'mahasiswa' && !/^\d{5,20}$/.test(out.nomor_induk))
      throw new HttpError(400, 'NIM harus berupa angka (5-20 digit)');
    if (role === 'dosen' && !/^\d{10}$/.test(out.nomor_induk))
      throw new HttpError(400, 'NIDN harus 10 digit angka');
  }
  if (body.email !== undefined) {
    out.email = str(body.email).toLowerCase();
    if (!EMAIL_RE.test(out.email)) throw new HttpError(400, 'Format email/gmail tidak valid');
  }
  if (body.alamat !== undefined) {
    out.alamat = str(body.alamat);
    if (out.alamat.length > 200) throw new HttpError(400, 'Alamat maksimal 200 karakter');
  }
  return out;
}

function assertUnique(fields, exceptId = 0) {
  if (fields.email && db.prepare('SELECT 1 FROM users WHERE email = ? AND id != ?').get(fields.email, exceptId))
    throw new HttpError(409, 'Email sudah dipakai akun lain');
  if (fields.nomor_induk && db.prepare('SELECT 1 FROM users WHERE nomor_induk = ? AND id != ?').get(fields.nomor_induk, exceptId))
    throw new HttpError(409, 'NIM/NIDN sudah dipakai akun lain');
}

function findManagedUser(id) {
  const u = db.prepare('SELECT * FROM users WHERE id = ?').get(Number(id));
  if (!u || u.role === 'fakultas') throw new HttpError(404, 'Akun mahasiswa/dosen tidak ditemukan');
  return u;
}

route('GET', '/api/users', (req) => {
  requireAuth(req, ['fakultas']);
  const url = new URL(req.url, 'http://x');
  const role = url.searchParams.get('role');
  const q = (url.searchParams.get('q') || '').trim().toLowerCase();
  if (role && !['mahasiswa', 'dosen'].includes(role)) throw new HttpError(400, 'Role harus mahasiswa atau dosen');
  let rows = db
    .prepare(`SELECT * FROM users WHERE role IN ('mahasiswa','dosen') ${role ? 'AND role = ?' : ''} ORDER BY role, nama`)
    .all(...(role ? [role] : []));
  if (q)
    rows = rows.filter((u) =>
      [u.nama, u.nomor_induk, u.email, u.alamat].some((v) => (v || '').toLowerCase().includes(q))
    );
  return { data: { users: rows.map(publicUser) } };
});

route('POST', '/api/users', (req, p, body) => {
  requireAuth(req, ['fakultas']);
  const role = str(body.role);
  if (!['mahasiswa', 'dosen'].includes(role)) throw new HttpError(400, 'Role harus mahasiswa atau dosen');
  for (const k of ['nama', 'nomor_induk', 'email'])
    if (!str(body[k])) throw new HttpError(400, `${k === 'nomor_induk' ? ID_LABEL[role] : k} wajib diisi`);
  const f = parseUserFields(body, role);
  assertUnique(f);
  let password = typeof body.password === 'string' ? body.password : '';
  let digenerate = false;
  if (!password) {
    password = generatePassword();
    digenerate = true;
  } else if (password.length < 6) throw new HttpError(400, 'Password minimal 6 karakter');

  const info = db
    .prepare(
      `INSERT INTO users (nama, email, password_hash, role, nomor_induk, alamat, created_at)
       VALUES (?, ?, ?, ?, ?, ?, ?)`
    )
    .run(f.nama, f.email, hashPassword(password), role, f.nomor_induk, f.alamat || null, new Date().toISOString());
  const user = db.prepare('SELECT * FROM users WHERE id = ?').get(Number(info.lastInsertRowid));
  return { status: 201, data: { user: publicUser(user), password_awal: password, digenerate } };
});

route('PATCH', '/api/users/:id', (req, p, body) => {
  requireAuth(req, ['fakultas']);
  const u = findManagedUser(p.id);
  const f = parseUserFields(body, u.role);
  if (Object.keys(f).length === 0) throw new HttpError(400, 'Tidak ada data yang diubah');
  assertUnique(f, u.id);
  const merged = { nama: u.nama, email: u.email, nomor_induk: u.nomor_induk, alamat: u.alamat, ...f };
  db.prepare('UPDATE users SET nama = ?, email = ?, nomor_induk = ?, alamat = ? WHERE id = ?').run(
    merged.nama,
    merged.email,
    merged.nomor_induk,
    merged.alamat || null,
    u.id
  );
  return { data: { user: publicUser(db.prepare('SELECT * FROM users WHERE id = ?').get(u.id)) } };
});

// Hapus akun. Akun yang sudah punya pengaduan/survei tidak boleh dihapus (riwayat pengaduan harus utuh).
route('DELETE', '/api/users/:id', (req, p) => {
  requireAuth(req, ['fakultas']);
  const u = findManagedUser(p.id);
  const punya =
    db.prepare('SELECT 1 FROM complaints WHERE user_id = ?').get(u.id) ||
    db.prepare('SELECT 1 FROM surveys WHERE user_id = ?').get(u.id);
  if (punya)
    throw new HttpError(409, 'Akun tidak bisa dihapus karena sudah punya pengaduan/survei. Ubah datanya atau reset sandinya saja.');
  db.prepare('DELETE FROM users WHERE id = ?').run(u.id);
  return { data: { message: `Akun ${u.nama} dihapus` } };
});

// Lupa sandi: Fakultas mengatur ulang. Jika "password" kosong, dibuat sandi sementara acak.
route('POST', '/api/users/:id/reset-password', (req, p, body) => {
  requireAuth(req, ['fakultas']);
  const u = findManagedUser(p.id);
  let password = typeof body.password === 'string' ? body.password : '';
  let digenerate = false;
  if (!password) {
    password = generatePassword();
    digenerate = true;
  } else if (password.length < 6) throw new HttpError(400, 'Password minimal 6 karakter');
  db.prepare('UPDATE users SET password_hash = ? WHERE id = ?').run(hashPassword(password), u.id);
  return { data: { user: publicUser(u), password_baru: password, digenerate } };
});

route('GET', '/api/health', () => ({ data: { ok: true, waktu: new Date().toISOString() } }));

// ---------------------------------------------------------------- Server
const server = http.createServer(async (req, res) => {
  if (req.method === 'OPTIONS') return send(res, 204, {});
  try {
    const pathname = new URL(req.url, 'http://x').pathname;
    for (const r of routes) {
      if (r.method !== req.method) continue;
      const m = r.regex.exec(pathname);
      if (!m) continue;
      const params = {};
      r.keys.forEach((k, i) => (params[k] = m[i + 1]));
      const body = req.method === 'POST' || req.method === 'PATCH' ? await readJson(req, r.maxBody) : {};
      const out = r.handler(req, params, body);
      if (out.raw) {
        res.writeHead(200, {
          'Content-Type': out.raw.mime,
          'Content-Length': out.raw.buffer.length,
          'Cache-Control': 'private, max-age=86400',
          'Access-Control-Allow-Origin': '*',
        });
        return res.end(out.raw.buffer);
      }
      return send(res, out.status || 200, out.data);
    }
    send(res, 404, { error: 'Endpoint tidak ditemukan' });
  } catch (e) {
    if (e instanceof HttpError) return send(res, e.status, { error: e.message });
    console.error(e);
    send(res, 500, { error: 'Terjadi kesalahan pada server' });
  }
});

if (require.main === module) {
  server.listen(PORT, '0.0.0.0', () => console.log(`API berjalan di http://0.0.0.0:${PORT}`));
}

module.exports = { server };
