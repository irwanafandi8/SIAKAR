# PRD.md — Product Requirements SIAKAR

Turunan dari laporan analisis (Kelompok 9, D4RPL.2C) dan `DECISIONS.md`. Jika ada konflik, `DECISIONS.md` menang.

## 1. Ringkasan Produk

SIAKAR adalah aplikasi absensi karyawan berbasis mobile (Android) yang memverifikasi **identitas lewat pengenalan wajah** dan **lokasi lewat GPS (geofencing)**, dilengkapi alur pengajuan izin/cuti, serta panel web untuk Admin/HRD. Model pengenalan wajah dibangun dari nol dengan dataset sintetis.

**Masalah yang dijawab** (laporan §1.2): (1) titip absen, (2) absen di luar lokasi, (3) rekap manual lambat, (4) izin tidak terlacak, (5) data biometrik sensitif.

## 2. Pengguna

| Persona | Platform | Tujuan utama |
|---|---|---|
| **Karyawan** | Aplikasi mobile | Absen masuk/pulang cepat, lihat riwayat, ajukan izin |
| **Atasan** | Aplikasi mobile (peran atasan) | Menyetujui/menolak izin, melihat rekap bawahan |
| **Admin/HRD** | Web (Blade) | Kelola data master, koreksi absensi, laporan rekap |

## 3. Lingkup (MoSCoW)

Urutan kerja mengikuti `TASKS.md`. Prioritas dapat diubah kelompok; ubah di sini dan di TASKS.

### Must (harus ada untuk demo)

| ID | Fitur | Aktor | Rujukan laporan |
|---|---|---|---|
| FR-01 | Login/logout, pengikatan perangkat | Semua | Use case Login |
| FR-02 | Registrasi wajah (3–5 foto) | Karyawan | BR-02 |
| FR-03 | Absen masuk: wajah + lokasi + shift → status Hadir/Terlambat | Karyawan | BR-01, BR-03 |
| FR-04 | Absen pulang | Karyawan | BR-01 |
| FR-05 | Riwayat absensi pribadi | Karyawan | Use case Lihat Riwayat |
| FR-10 | Admin: CRUD karyawan (+ departemen, jabatan), shift + jadwal, lokasi kantor | Admin | BR-05 |
| FR-13 | Admin: rekap absensi (tabel dengan filter periode) | Admin | BR-06 |
| ML-01 | Model embedding wajah buatan sendiri + evaluasi + ekspor TFLite | — | (baru, syarat AI) |
| ML-02 | Detektor wajah buatan sendiri (validasi wajah dalam oval) | — | (baru, syarat AI) |

### Should (kerjakan setelah Must stabil)

| ID | Fitur | Aktor | Rujukan |
|---|---|---|---|
| FR-06 | Pengajuan izin/sakit/cuti (+ lampiran) dan daftar status | Karyawan | BR-04 |
| FR-07 | Setujui/tolak izin (atasan langsung); mencatat status pada rentang tanggal | Atasan | BR-04 |
| FR-08 | Rekap kehadiran bawahan | Atasan | BR-07 |
| FR-11 | Admin: hari libur | Admin | BR-05 |
| FR-12 | Admin: koreksi absensi (keterangan wajib) | Admin | BR-06 |
| FR-14 | Ekspor rekap ke CSV | Admin | BR-06 |
| ML-03 | Liveness minimal L1 (challenge-response) | — | (baru) |
| ML-04 | Baseline klasik HOG/LBP + ablasi | — | (baru, bahan analisis) |

### Could (bila waktu tersisa)

Absen manual dengan persetujuan (fallback demo), ekspor PDF/Excel, dasbor dengan grafik tren, peta lokasi kantor di admin, notifikasi push, deteksi mock GPS, liveness L2 (kedip), job harian penanda `alpa`.

### Won't (di luar lingkup)

Build iOS, integrasi payroll/penggajian, mode offline, pengenalan 1:N (mencari wajah di antara semua karyawan), kuantisasi lanjutan, Admin berbasis Flutter web, mata kuliah Visi Komputer.

## 4. Alur Pengguna Utama

### 4.1 Registrasi wajah (FR-02)
Login → menu Registrasi Wajah → izin kamera → oval panduan → ambil 3–5 foto (depan, sedikit kiri/kanan) → detektor memvalidasi tiap foto → embedding tiap foto dihitung di perangkat → kirim ke server → server merata-ratakan, mengenkripsi, menyimpan → konfirmasi.

### 4.2 Absen masuk (FR-03)
Beranda → Absen Masuk → ambil GPS → kamera + oval → detektor → (liveness bila aktif) → embedding di perangkat → kirim `embedding + GPS + foto bukti` → server memeriksa (perangkat, jadwal, libur, radius, sudah absen?, kecocokan wajah) → simpan baris `absensi` dengan status → tampil hasil (status, jam, jarak, skor).

### 4.3 Izin (FR-06/07)
Karyawan mengisi form (jenis, tanggal, alasan, lampiran) → status `menunggu` → atasan menerima daftar → setuju/tolak → status berubah, rentang tanggal tercatat pada `absensi` bila disetujui → karyawan melihat status terbaru.

### 4.4 Admin (FR-10..14)
Login web → kelola master → pantau/koreksi absensi → lihat rekap → ekspor.

## 5. Aturan Bisnis (acuan implementasi)

Rujukan keputusan: D-60 s.d. D-69.

1. Waktu = **waktu server** (WIB). Waktu dari klien diabaikan untuk penentuan status.
2. Jarak = Haversine dari GPS ke tiap `lokasi_kantor`; lolos bila ada lokasi dengan `jarak ≤ radius_meter`. Lokasi terdekat yang lolos dicatat di `absensi.id_lokasi`.
3. Status masuk: `terlambat` bila `waktu_absen > shift.jam_masuk + toleransi_menit`; selain itu `hadir`.
4. Tidak ada jadwal di tanggal tersebut → tolak. Tanggal ada di `hari_libur` → tolak.
5. Maksimal satu baris `absensi` per karyawan per tanggal. Absen masuk kedua → tolak; absen pulang tanpa absen masuk → tolak.
6. Wajah cocok bila `cosine(embedding_masuk, embedding_terdaftar) ≥ ambang` (ambang dari `config/face.php`).
7. Perangkat harus sama dengan `pengguna.device_id`.
8. Izin hanya bisa diputuskan oleh atasan langsung pemohon.
9. Absen manual (Could): setelah 3 kali gagal verifikasi pada hari yang sama, ditawarkan pengajuan absen manual yang membutuhkan persetujuan atasan.

## 6. Kriteria Penerimaan (Given/When/Then)

**FR-02 Registrasi wajah**
- Given karyawan login dan belum punya data wajah, When mengambil ≥ 3 foto valid, Then data wajah tersimpan aktif dan menu Absen terbuka.
- Given foto tidak memuat wajah di dalam oval, When diambil, Then foto ditolak dan diminta ulang.
- Given data wajah sudah ada, When memilih Perbarui, Then embedding lama diganti setelah registrasi baru berhasil.

**FR-03 Absen masuk**
- Given wajah terdaftar, GPS di dalam radius, ada jadwal, bukan hari libur, When absen dengan wajah sendiri sebelum batas toleransi, Then baris `absensi` status `hadir`.
- Given kondisi sama tetapi setelah batas toleransi, Then status `terlambat`.
- Given GPS di luar radius, Then ditolak dengan `OUT_OF_RADIUS` dan tidak ada baris tersimpan.
- Given wajah orang lain (skor di bawah ambang), Then ditolak dengan `FACE_MISMATCH`.
- Given sudah absen masuk hari ini, Then ditolak dengan `ALREADY_CHECKED_IN`.
- Given perangkat berbeda dari yang terikat, Then ditolak dengan `DEVICE_MISMATCH`.

**FR-04 Absen pulang**
- Given sudah absen masuk, When absen pulang lolos verifikasi yang sama, Then `jam_pulang` dan koordinat pulang tersimpan pada baris yang sama.

**FR-06/07 Izin**
- Given pemohon mengisi form valid, Then pengajuan berstatus `menunggu` dan muncul di daftar atasan langsung.
- Given atasan menyetujui, Then status `disetujui`, `id_penyetuju` terisi, dan `absensi` mencatat status izin/sakit/cuti pada tiap tanggal dalam rentang.
- Given atasan menolak, Then status `ditolak` dan pemohon melihat hasilnya.
- Given pengguna bukan atasan langsung, When mencoba memutuskan, Then ditolak (403).

**FR-10/12/13 Admin**
- Given admin login web, When mengubah shift/lokasi/jadwal, Then absensi berikutnya memakai nilai baru.
- Given admin mengoreksi absensi, Then perubahan tersimpan dan `keterangan` wajib terisi.
- Given admin memilih periode, Then rekap menampilkan jumlah hadir, terlambat, izin/sakit/cuti, alpa per karyawan.

**ML-01/02**
- Given golden images, Then embedding Dart ≈ embedding Python (cosine ≥ 0.99) dan TFLite ≈ Keras (≥ 0.999).
- Given evaluasi §6 ML_SPEC, Then laporan hasil dan analisis tersedia dan menyebut keterbatasan selisih domain.

## 7. Kebutuhan Non-Fungsional

| Kategori | Kebutuhan | Cara verifikasi |
|---|---|---|
| Kinerja | Absen ujung-ke-ujung < 5 detik (**target, harus diukur**) | Uji di ponsel asli, 10 kali, catat rata-rata |
| Keamanan | Password `bcrypt`; token Sanctum; embedding terenkripsi; foto di disk privat; peran dicek di server | Tinjauan kode + uji akses |
| Privasi | Foto mentah bukan data pencocokan; hanya embedding yang dibandingkan | Tinjauan alur |
| Keandalan | Respons error terstruktur (kode seperti `FACE_MISMATCH`) | Uji API |
| Kegunaan | UI Indonesia; langkah absen minimal; pesan error ramah | Uji coba pengguna |
| Portabilitas | Android; praproses identik Dart = Python | Uji paritas |
| Kompatibilitas data | Skema mengikuti kamus data + penyesuaian DECISIONS §4.1 | Migrasi + seeder |

## 8. Skenario Demo (kriteria sukses akhir)

1. Admin login web, melihat data master dan jadwal.
2. Karyawan login, registrasi wajah.
3. Absen masuk **berhasil** → `hadir` (atau `terlambat` dengan jam yang diatur).
4. Absen masuk di luar radius → **ditolak**.
5. Wajah berbeda → **ditolak**.
6. Karyawan mengajukan izin → atasan menyetujui → status terlihat.
7. Admin melihat rekap dan mengunduh CSV.
8. Presentasi hasil evaluasi model (klasifikasi, verifikasi, perbandingan baseline, keterbatasan).

Karena selisih domain sintetis→nyata (R-02), skenario 3 dan 5 harus dicoba **sebelum** demo; siapkan rencana bila akurasi di kamera nyata rendah (tunjukkan hasil evaluasi dan alur penuh pada data uji, jangan menjanjikan akurasi kamera).

## 9. Asumsi dan Pertanyaan Terbuka

Lihat `DECISIONS.md` §6 (Q-1 s.d. Q-7) dan §7 (risiko).

## 10. Ketertelusuran ke Laporan Analisis

| Artefak laporan | Dipakai di |
|---|---|
| Use case, DFD 0/1/2 | alur §4, aturan §5, `DESIGN.md` §3 |
| ERD + kamus data | `DESIGN.md` §5 (skema), `API.md` |
| Rancangan antarmuka (bab 8) | `DESIGN.md` §6 (layar) |
| BR-01..07 | §3 (kolom Rujukan) |
