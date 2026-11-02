// Tes alur API end-to-end memakai database sementara.
// Jalankan: node test.js
process.env.DB_PATH = process.env.DB_PATH || require('node:path').join(require('node:os').tmpdir(), `pengaduan-test-${Date.now()}.db`);
process.env.UPLOAD_DIR = process.env.UPLOAD_DIR || require('node:path').join(require('node:os').tmpdir(), `pengaduan-uploads-${Date.now()}`);
const assert = require('node:assert/strict');
const { server } = require('./server');
const { db } = require('./db');

const PORT = 3111;
const BASE = `http://127.0.0.1:${PORT}/api`;

async function call(method, path, { token, body } = {}) {
  const res = await fetch(BASE + path, {
    method,
    headers: { 'Content-Type': 'application/json', ...(token ? { Authorization: `Bearer ${token}` } : {}) },
    body: body ? JSON.stringify(body) : undefined,
  });
  return { status: res.status, data: await res.json() };
}

async function main() {
  await new Promise((r) => server.listen(PORT, r));
  let n = 0;
  const ok = (name) => console.log(`  ok ${++n}. ${name}`);

  // Auth
  let r = await call('GET', '/complaints/mine');
  assert.equal(r.status, 401); ok('endpoint butuh login (401 tanpa token)');

  r = await call('POST', '/auth/register', { body: { nama: 'X', email: 'x@x.id', password: 'rahasia1', role: 'mahasiswa' } });
  assert.equal(r.status, 404); ok('pendaftaran mandiri dinonaktifkan');

  // Data awal: 4 dosen + 4 mahasiswa, semua harus bisa login.
  for (const [role, id, pw] of [
    ['dosen', '7104313441', 'dosen123'], ['dosen', '7104313620', 'dosen123'], ['dosen', '7104313526', 'dosen123'], ['dosen', '5116201014', 'dosen123'],
    ['mahasiswa', '2024520018', 'coba1234'], ['mahasiswa', '2024520051', 'coba1234'], ['mahasiswa', '2024520037', 'coba1234'], ['mahasiswa', '2024520022', 'coba1234'],
  ]) {
    r = await call('POST', '/auth/login', { body: { role, identifier: id, password: pw } });
    assert.equal(r.status, 200, `seed ${role} ${id}`);
  }
  r = await call('POST', '/auth/login', { body: { role: 'dosen', identifier: '7104313441', password: 'dosen123' } });
  assert.equal(r.data.user.nama, 'Sholeh Rachmatullah, S.Kom., M.Kom.');
  assert.equal(r.data.user.email, 'sholeh@unira.ac.id'); ok('data awal: 4 dosen + 4 mahasiswa bisa login');
  db.prepare(`DELETE FROM users WHERE role IN ('mahasiswa','dosen')`).run(); // tes di bawah memakai akun uji sendiri

  // Akun uji dibuat lewat API fakultas.
  r = await call('POST', '/auth/login', { body: { role: 'fakultas', identifier: 'admin@fakultas.ac.id', password: 'admin123' } });
  const fakSetup = r.data.token;
  for (const [role, nama, induk, email, alamat, pw] of [
    ['mahasiswa', 'Rizky Pratama', '2211101001', 'rizky.pratama.ft@gmail.com', 'Jl. Melati No. 12, Surabaya', 'mahasiswa123'],
    ['mahasiswa', 'Siti Nurhaliza', '2211102014', 'siti.nurhaliza.ft@gmail.com', 'Jl. Kenanga No. 7, Sidoarjo', 'mahasiswa123'],
    ['mahasiswa', 'Andi Wijaya', '2211103027', 'andi.wijaya.ft@gmail.com', 'Jl. Mawar No. 33, Gresik', 'mahasiswa123'],
    ['mahasiswa', 'Dewi Lestari', '2211104038', 'dewi.lestari.ft@gmail.com', 'Jl. Anggrek No. 5, Malang', 'mahasiswa123'],
    ['dosen', 'Sholeh Rachmatullah, S.Kom., M.Kom.', '7104313441', 'sholeh@unira.ac.id', 'Jl Raya Nyalaran 199 Pamekasan', 'dosen123'],
    ['dosen', 'Dr. Retno Wulandari, S.T., M.Eng.', '0711018001', 'retno.wulandari.ft@gmail.com', 'Jl. Gubeng Raya No. 48, Surabaya', 'dosen123'],
    ['dosen', 'Ir. Agus Setiawan, M.Sc.', '0712027202', 'agus.setiawan.ft@gmail.com', 'Jl. Pahlawan No. 9, Sidoarjo', 'dosen123'],
    ['dosen', 'Ir. Maya Puspitasari, M.T.', '0715038503', 'maya.puspitasari.ft@gmail.com', 'Jl. Ijen No. 15, Malang', 'dosen123'],
  ]) {
    r = await call('POST', '/users', { token: fakSetup, body: { role, nama, nomor_induk: induk, email, alamat } });
    assert.equal(r.status, 201, `buat ${nama}`);
    r = await call('POST', `/users/${r.data.user.id}/reset-password`, { token: fakSetup, body: { password: pw } });
    assert.equal(r.status, 200);
  }
  // Login per role
  r = await call('POST', '/auth/login', { body: { role: 'mahasiswa', identifier: '2211101001', password: 'mahasiswa123' } });
  assert.equal(r.status, 200);
  assert.equal(r.data.user.nama, 'Rizky Pratama');
  assert.equal(r.data.user.email, 'rizky.pratama.ft@gmail.com');
  assert.equal(r.data.user.alamat, 'Jl. Melati No. 12, Surabaya');
  const mhs = r.data.token; ok('mahasiswa login pakai NIM + password');

  r = await call('POST', '/auth/login', { body: { role: 'dosen', identifier: '7104313441', password: 'dosen123' } });
  assert.equal(r.status, 200);
  assert.equal(r.data.user.role, 'dosen');
  const dsn = r.data.token; ok('dosen login pakai NIDN + password');

  r = await call('POST', '/auth/login', { body: { role: 'fakultas', identifier: 'admin@fakultas.ac.id', password: 'admin123' } });
  assert.equal(r.status, 200);
  const fak = r.data.token; ok('fakultas login pakai email + password');

  for (const [role, id, pw] of [
    ['mahasiswa', '2211102014', 'mahasiswa123'], ['mahasiswa', '2211103027', 'mahasiswa123'], ['mahasiswa', '2211104038', 'mahasiswa123'],
    ['dosen', '0711018001', 'dosen123'], ['dosen', '0712027202', 'dosen123'], ['dosen', '0715038503', 'dosen123'],
  ]) {
    r = await call('POST', '/auth/login', { body: { role, identifier: id, password: pw } });
    assert.equal(r.status, 200, `${role} ${id}`);
  }
  ok('semua akun uji (4 mahasiswa + 4 dosen) bisa login');

  r = await call('POST', '/auth/login', { body: { role: 'mahasiswa', identifier: '2211101001', password: 'salah' } });
  assert.equal(r.status, 401); ok('password salah ditolak');

  r = await call('POST', '/auth/login', { body: { role: 'mahasiswa', identifier: '7104313441', password: 'dosen123' } });
  assert.equal(r.status, 401); ok('NIDN dosen tidak bisa dipakai login sebagai mahasiswa');

  r = await call('POST', '/auth/login', { body: { role: 'mahasiswa', identifier: 'rizky.pratama.ft@gmail.com', password: 'mahasiswa123' } });
  assert.equal(r.status, 401); ok('mahasiswa tidak login pakai email (harus NIM)');

  // Kelola akun (fakultas)
  r = await call('GET', '/users', { token: mhs });
  assert.equal(r.status, 403); ok('mahasiswa tidak boleh melihat daftar akun');

  r = await call('GET', '/users?role=mahasiswa', { token: fak });
  assert.equal(r.data.users.length, 4);
  assert.ok(r.data.users.every((u) => u.alamat && u.email && u.nomor_induk));
  r = await call('GET', '/users?role=dosen', { token: fak });
  assert.equal(r.data.users.length, 4);
  r = await call('GET', '/users?q=siti', { token: fak });
  assert.equal(r.data.users.length, 1); ok('fakultas melihat 4 mahasiswa + 4 dosen (nama, NIM/NIDN, gmail, alamat) & bisa cari');
  const siti = r.data.users[0];

  r = await call('POST', '/auth/login', { body: { role: 'mahasiswa', identifier: siti.nomor_induk, password: 'mahasiswa123' } });
  const sitiTokenLama = r.data.token;

  r = await call('POST', `/users/${siti.id}/reset-password`, { token: fak, body: {} });
  assert.equal(r.status, 200);
  assert.equal(r.data.digenerate, true);
  assert.ok(r.data.password_baru.length >= 8);
  const pwBaru = r.data.password_baru; ok('fakultas reset sandi lupa -> sandi sementara dibuat otomatis');

  r = await call('POST', '/auth/login', { body: { role: 'mahasiswa', identifier: siti.nomor_induk, password: 'mahasiswa123' } });
  assert.equal(r.status, 401);
  r = await call('POST', '/auth/login', { body: { role: 'mahasiswa', identifier: siti.nomor_induk, password: pwBaru } });
  assert.equal(r.status, 200); ok('sandi lama ditolak, sandi baru bisa login');

  r = await call('GET', '/auth/me', { token: sitiTokenLama });
  assert.equal(r.status, 401); ok('sesi lama otomatis berakhir setelah sandi di-reset');

  r = await call('POST', `/users/${siti.id}/reset-password`, { token: fak, body: { password: 'abc' } });
  assert.equal(r.status, 400);
  r = await call('POST', `/users/${siti.id}/reset-password`, { token: fak, body: { password: 'sandiBaru1' } });
  assert.equal(r.data.password_baru, 'sandiBaru1'); ok('reset dengan sandi pilihan fakultas (min. 6 karakter)');

  r = await call('PATCH', `/users/${siti.id}`, { token: fak, body: { email: 'siti.baru@gmail.com', alamat: 'Jl. Baru No. 1, Surabaya', nama: 'Siti N. Halimah' } });
  assert.equal(r.status, 200);
  assert.equal(r.data.user.email, 'siti.baru@gmail.com');
  assert.equal(r.data.user.alamat, 'Jl. Baru No. 1, Surabaya'); ok('fakultas memperbarui nama/gmail/alamat');

  r = await call('PATCH', `/users/${siti.id}`, { token: fak, body: { nomor_induk: '2211101001' } });
  assert.equal(r.status, 409); ok('NIM kembar ditolak');
  r = await call('PATCH', `/users/${siti.id}`, { token: fak, body: { email: 'rizky.pratama.ft@gmail.com' } });
  assert.equal(r.status, 409); ok('email kembar ditolak');
  r = await call('PATCH', `/users/${siti.id}`, { token: fak, body: { nomor_induk: '12ab' } });
  assert.equal(r.status, 400); ok('format NIM tidak valid ditolak');

  r = await call('POST', '/users', { token: fak, body: { role: 'dosen', nama: 'Ir. Tes', nomor_induk: '1234', email: 'tes@gmail.com' } });
  assert.equal(r.status, 400); ok('NIDN harus 10 digit');
  r = await call('POST', '/users', { token: fak, body: { role: 'mahasiswa', nama: 'Mhs Baru', nomor_induk: '2211105049', email: 'mhs.baru@gmail.com', alamat: 'Jl. Tes 1' } });
  assert.equal(r.status, 201);
  const pwAwal = r.data.password_awal;
  r = await call('POST', '/auth/login', { body: { role: 'mahasiswa', identifier: '2211105049', password: pwAwal } });
  assert.equal(r.status, 200); ok('fakultas menambah mahasiswa baru, langsung bisa login dengan sandi awal');

  const baruId = (await call('GET', '/users?q=2211105049', { token: fak })).data.users[0].id;
  r = await call('DELETE', `/users/${baruId}`, { token: mhs });
  assert.equal(r.status, 403);
  r = await call('DELETE', `/users/${baruId}`, { token: fak });
  assert.equal(r.status, 200);
  r = await call('GET', '/users?q=2211105049', { token: fak });
  assert.equal(r.data.users.length, 0); ok('fakultas menghapus akun (mahasiswa tidak boleh)');

  r = await call('PATCH', '/users/1', { token: fak, body: { nama: 'Hacker' } });
  assert.equal(r.status, 404); ok('akun fakultas tidak bisa diubah lewat API kelola akun');

  // Pengaduan
  r = await call('POST', '/complaints', { token: mhs, body: { judul: 'AC rusak', lokasi: 'Gedung A R.201', deskripsi: 'AC tidak dingin' } });
  assert.equal(r.status, 201);
  const c1 = r.data.complaint;
  assert.match(c1.kode, /^ADU-\d{6}-[A-Z2-9]{5}$/);
  assert.equal(c1.status, 'menunggu');
  assert.equal(c1.bisa_survei, false);
  const selisihJam = (new Date(c1.batas_waktu) - new Date(c1.created_at)) / 36e5;
  assert.equal(selisihJam, 24); ok(`buat pengaduan, kode unik ${c1.kode}, batas 24 jam`);

  r = await call('POST', '/complaints', { token: dsn, body: { judul: 'Proyektor mati', lokasi: 'Lab 3', deskripsi: 'Tidak menyala' } });
  const c2 = r.data.complaint;
  assert.notEqual(c1.kode, c2.kode); ok('dosen buat pengaduan, kode berbeda');

  r = await call('POST', '/complaints', { token: fak, body: { judul: 'x', lokasi: 'y', deskripsi: 'z' } });
  assert.equal(r.status, 403); ok('fakultas tidak boleh membuat pengaduan');

  r = await call('GET', '/complaints/mine', { token: mhs });
  assert.equal(r.data.complaints.length, 1); ok('riwayat hanya milik sendiri');

  // Lacak
  r = await call('GET', `/complaints/track/${c1.kode.toLowerCase()}`, { token: mhs });
  assert.equal(r.status, 200);
  assert.equal(r.data.complaint.milik_saya, true);
  assert.equal(r.data.riwayat.length, 1); ok('lacak via kode (tidak peka huruf besar/kecil)');

  r = await call('GET', '/complaints/track/ADU-000000-XXXXX', { token: mhs });
  assert.equal(r.status, 404); ok('kode tidak ada -> 404');

  // Survei belum boleh (belum selesai & belum lewat batas)
  r = await call('POST', '/surveys', { token: mhs, body: { complaint_id: c1.id, rating: 'baik' } });
  assert.equal(r.status, 422); ok('survei ditolak sebelum selesai / sebelum lewat batas');

  // Fakultas
  r = await call('GET', '/complaints', { token: mhs });
  assert.equal(r.status, 403); ok('mahasiswa tidak bisa melihat semua pengaduan');

  r = await call('GET', '/complaints', { token: fak });
  assert.equal(r.data.complaints.length, 2);
  assert.equal(r.data.complaints[0].pelapor.nama.length > 0, true); ok('fakultas melihat semua pengaduan + pelapor');

  r = await call('PATCH', `/complaints/${c1.id}/status`, { token: fak, body: { status: 'diproses', catatan: 'Teknisi dijadwalkan' } });
  assert.equal(r.data.complaint.status, 'diproses'); ok('fakultas ubah status -> diproses');

  r = await call('PATCH', `/complaints/${c1.id}/status`, { token: fak, body: { status: 'ngawur' } });
  assert.equal(r.status, 400); ok('status tidak valid ditolak');

  r = await call('GET', `/complaints/track/${c1.kode}`, { token: mhs });
  assert.equal(r.data.riwayat.length, 2); ok('riwayat pelacakan bertambah');

  // Survei setelah selesai
  await call('PATCH', `/complaints/${c1.id}/status`, { token: fak, body: { status: 'selesai', catatan: 'AC sudah diperbaiki' } });
  r = await call('GET', `/complaints/track/${c1.kode}`, { token: mhs });
  assert.equal(r.data.complaint.bisa_survei, true); ok('bisa_survei = true setelah selesai');

  r = await call('POST', '/surveys', { token: dsn, body: { complaint_id: c1.id, rating: 'baik' } });
  assert.equal(r.status, 403); ok('non-pelapor tidak bisa mengisi survei');

  r = await call('POST', '/surveys', { token: mhs, body: { complaint_id: c1.id, rating: 'luar_biasa' } });
  assert.equal(r.status, 400); ok('rating tidak valid ditolak');

  r = await call('POST', '/surveys', { token: mhs, body: { complaint_id: c1.id, rating: 'sangat_baik' } }); // tanpa keterangan
  assert.equal(r.status, 201); ok('survei tanpa keterangan (opsional) berhasil');

  r = await call('POST', '/surveys', { token: mhs, body: { complaint_id: c1.id, rating: 'baik' } });
  assert.equal(r.status, 409); ok('survei ganda ditolak');

  // Survei setelah lewat batas 1 hari walau BELUM ditangani
  r = await call('POST', '/surveys', { token: dsn, body: { complaint_id: c2.id, rating: 'kurang', keterangan: 'Belum ditangani' } });
  assert.equal(r.status, 422); ok('c2 (menunggu, belum lewat batas) belum bisa disurvei');

  const lalu = new Date(Date.now() - 25 * 36e5).toISOString();
  db.prepare('UPDATE complaints SET created_at = ?, batas_waktu = ? WHERE id = ?').run(lalu, new Date(Date.now() - 36e5).toISOString(), c2.id);

  r = await call('GET', `/complaints/track/${c2.kode}`, { token: dsn });
  assert.equal(r.data.complaint.lewat_batas, true);
  assert.equal(r.data.complaint.status, 'menunggu');
  assert.equal(r.data.complaint.bisa_survei, true); ok('lewat batas 1 hari, status masih menunggu -> bisa_survei = true');

  r = await call('POST', '/surveys', { token: dsn, body: { complaint_id: c2.id, rating: 'kurang', keterangan: 'Belum ditangani lebih dari 1 hari' } });
  assert.equal(r.status, 201); ok('survei berhasil walau pengaduan belum ditangani (lewat batas)');

  // Statistik grafik
  r = await call('GET', '/surveys/stats', { token: mhs });
  assert.equal(r.data.total, 2);
  assert.equal(r.data.sangat_baik.persen, 50);
  assert.equal(r.data.baik.persen, 0);
  assert.equal(r.data.kurang.persen, 50); ok('statistik grafik: 50% sangat baik, 0% baik, 50% kurang');

  r = await call('GET', '/surveys', { token: fak });
  assert.equal(r.data.surveys.length, 2); ok('fakultas melihat daftar ulasan');

  r = await call('GET', '/dashboard', { token: fak });
  assert.equal(r.data.total, 2);
  assert.equal(r.data.selesai, 1);
  assert.equal(r.data.menunggu, 1);
  assert.equal(r.data.lewat_batas, 1); ok('dashboard fakultas (total, per status, lewat batas)');

  r = await call('GET', '/users?q=2211101001', { token: fak });
  r = await call('DELETE', `/users/${r.data.users[0].id}`, { token: fak });
  assert.equal(r.status, 409); ok('akun yang sudah punya pengaduan tidak bisa dihapus');


  // ---------------------------------------------------------------- Foto pengaduan
  // PNG 1x1 valid
  const png = Buffer.from('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==', 'base64');
  const pngB64 = png.toString('base64');

  r = await call('POST', '/complaints', { token: mhs, body: { judul: 'Atap bocor', lokasi: 'Gedung B', deskripsi: 'Bocor saat hujan', foto: [{ nama: 'a.png', data: pngB64 }, `data:image/png;base64,${pngB64}`] } });
  assert.equal(r.status, 201);
  assert.equal(r.data.complaint.foto.length, 2);
  const c3 = r.data.complaint; ok('mahasiswa upload 2 foto saat membuat pengaduan');

  const resFoto = await fetch(`http://127.0.0.1:${PORT}${c3.foto[0].url}`, { headers: { Authorization: `Bearer ${mhs}` } });
  assert.equal(resFoto.status, 200);
  assert.equal(resFoto.headers.get('content-type'), 'image/png');
  assert.deepEqual(Buffer.from(await resFoto.arrayBuffer()), png); ok('foto bisa diambil kembali (butuh token)');

  const tanpaToken = await fetch(`http://127.0.0.1:${PORT}${c3.foto[0].url}`);
  assert.equal(tanpaToken.status, 401); ok('foto tanpa login ditolak (401)');

  r = await call('POST', '/complaints', { token: dsn, body: { judul: 'Kursi patah', lokasi: 'Lab 1', deskripsi: 'Patah', foto: [{ data: pngB64 }] } });
  assert.equal(r.status, 201);
  assert.equal(r.data.complaint.foto.length, 1); ok('dosen juga bisa upload foto');

  r = await call('POST', '/complaints', { token: mhs, body: { judul: 'x', lokasi: 'y', deskripsi: 'z', foto: [{ data: Buffer.from('bukan gambar sama sekali').toString('base64') }] } });
  assert.equal(r.status, 400); ok('file non-gambar ditolak');

  r = await call('POST', '/complaints', { token: mhs, body: { judul: 'x', lokasi: 'y', deskripsi: 'z', foto: [pngB64, pngB64, pngB64, pngB64] } });
  assert.equal(r.status, 400); ok('lebih dari 3 foto ditolak');

  r = await call('POST', '/complaints', { token: mhs, body: { judul: 'Tanpa foto', lokasi: 'y', deskripsi: 'z' } });
  assert.equal(r.status, 201);
  assert.deepEqual(r.data.complaint.foto, []); ok('foto opsional: pengaduan tanpa foto tetap bisa dibuat');
  const c5 = r.data.complaint;

  r = await call('GET', `/complaints/track/${c3.kode}`, { token: fak });
  assert.equal(r.data.complaint.foto.length, 2); ok('fakultas melihat foto pada detail pengaduan');

  // ---------------------------------------------------------------- Beranda informasi laporan
  r = await call('GET', '/complaints/aktif', { token: mhs });
  assert.equal(r.status, 200);
  const kodeMhs = r.data.complaints.map((c) => c.kode);
  assert.ok(kodeMhs.includes(c3.kode) && kodeMhs.includes(c5.kode));
  assert.ok(kodeMhs.includes(c2.kode), 'pengaduan dosen tampil di beranda mahasiswa');
  assert.ok(!kodeMhs.includes(c1.kode), 'c1 sudah selesai -> hilang dari beranda');
  assert.ok(r.data.complaints.every((c) => ['menunggu', 'diproses'].includes(c.status)));
  assert.ok(r.data.complaints.every((c) => !c.pelapor), 'identitas pelapor tidak dibocorkan');
  assert.ok(r.data.complaints.find((c) => c.kode === c3.kode).milik_saya === true);
  assert.ok(r.data.complaints.find((c) => c.kode === c2.kode).milik_saya === false); ok('beranda mahasiswa: semua pengaduan berjalan (termasuk dosen), tanpa nama pelapor');

  r = await call('GET', '/complaints/aktif', { token: dsn });
  assert.equal(r.data.complaints.length, 4);
  assert.ok(r.data.complaints.every((c) => !c.pelapor)); ok('beranda dosen: melihat pengaduan mahasiswa & dosen lain');

  r = await call('GET', '/complaints/aktif', { token: fak });
  const aktifFak = r.data.complaints.map((c) => c.kode);
  assert.equal(r.data.complaints.length, 4);
  assert.ok(!aktifFak.includes(c1.kode));
  assert.ok(r.data.complaints[0].pelapor.nama); ok('beranda fakultas: semua pengaduan masuk yang belum selesai/ditolak');

  await call('PATCH', `/complaints/${c3.id}/status`, { token: fak, body: { status: 'ditolak', catatan: 'Bukan kewenangan fakultas' } });
  r = await call('GET', '/complaints/aktif', { token: mhs });
  assert.ok(!r.data.complaints.some((c) => c.kode === c3.kode)); ok('status ditolak -> pengaduan hilang dari beranda');
  r = await call('GET', '/complaints/aktif', { token: fak });
  assert.ok(!r.data.complaints.some((c) => c.kode === c3.kode)); ok('status ditolak -> hilang juga dari beranda fakultas');

  // ---------------------------------------------------------------- Pengaduan fakultas per status + riwayat 24 jam
  r = await call('GET', '/complaints?status=menunggu', { token: fak });
  assert.ok(r.data.complaints.length === 3 && r.data.complaints.every((c) => c.status === 'menunggu')); ok('daftar pengaduan fakultas: tab Menunggu');

  r = await call('GET', '/complaints?status=selesai', { token: fak });
  assert.deepEqual(r.data.complaints.map((c) => c.kode), [c1.kode]);
  r = await call('GET', '/complaints?status=ditolak', { token: fak });
  assert.deepEqual(r.data.complaints.map((c) => c.kode), [c3.kode]);
  r = await call('GET', '/complaints?status=riwayat', { token: fak });
  assert.equal(r.data.complaints.length, 0); ok('selesai/ditolak < 24 jam masih di tab statusnya, riwayat kosong');

  const enamHari = new Date(Date.now() - 23 * 36e5).toISOString();
  db.prepare('UPDATE complaints SET updated_at = ? WHERE id = ?').run(enamHari, c1.id);
  r = await call('GET', '/complaints?status=selesai', { token: fak });
  assert.deepEqual(r.data.complaints.map((c) => c.kode), [c1.kode]);
  r = await call('GET', '/complaints?status=riwayat', { token: fak });
  assert.equal(r.data.complaints.length, 0); ok('selesai 23 jam lalu masih di tab Selesai (belum 24 jam)');

  const delapanHari = new Date(Date.now() - 25 * 36e5).toISOString();
  db.prepare('UPDATE complaints SET updated_at = ? WHERE id = ?').run(delapanHari, c1.id);

  r = await call('GET', '/complaints?status=selesai', { token: fak });
  assert.equal(r.data.complaints.length, 0);
  r = await call('GET', '/complaints?status=riwayat', { token: fak });
  assert.deepEqual(r.data.complaints.map((c) => c.kode), [c1.kode]);
  assert.equal(r.data.complaints[0].diarsipkan, true); ok('selesai > 24 jam pindah ke Riwayat');

  r = await call('GET', '/complaints?status=semua', { token: fak });
  assert.ok(!r.data.complaints.some((c) => c.kode === c1.kode));
  assert.ok(r.data.complaints.some((c) => c.kode === c3.kode)); ok('tab Semua tidak memuat yang sudah diarsipkan');

  db.prepare('UPDATE complaints SET updated_at = ? WHERE id = ?').run(delapanHari, c3.id);
  r = await call('GET', '/complaints?status=riwayat', { token: fak });
  assert.equal(r.data.complaints.length, 2); ok('ditolak > 24 jam juga masuk Riwayat');

  r = await call('GET', '/complaints?status=riwayat', { token: mhs });
  assert.equal(r.status, 403);
  r = await call('GET', '/complaints?status=acak', { token: fak });
  assert.equal(r.status, 400); ok('riwayat khusus fakultas; status asal-asalan ditolak');

  r = await call('GET', '/complaints/mine', { token: mhs });
  assert.ok(r.data.complaints.some((c) => c.kode === c1.kode)); ok('riwayat milik mahasiswa tetap utuh (tidak ikut diarsipkan)');

  console.log(`\nSemua ${n} tes lulus.`);
  server.close();
  process.exit(0);
}

main().catch((e) => {
  console.error('\nTES GAGAL:', e);
  process.exit(1);
});
