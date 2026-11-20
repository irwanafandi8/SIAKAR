# Paket Prompt per Fitur — SIAKAR

Prompt ini disusun mengikuti `docs/project-kit/TASKS.md`. Satu prompt = satu sesi AI = satu tugas yang bisa diverifikasi. Jangan gabungkan beberapa prompt dalam satu sesi.

## Cara pakai

1. Salin `AGENTS.md` ke root repo dan folder `project-kit` ke `docs/project-kit/` (Prompt 0).
2. Buka sesi baru di AI coding agent (Claude Code, Cursor, dll.) untuk **setiap** prompt.
3. Tempel **Pembuka Standar** di bawah, lalu tempel prompt fitur yang dikerjakan.
4. Setelah selesai, jalankan perintah verifikasi sendiri, lalu `git commit` sebelum lanjut ke prompt berikutnya.
5. Jika AI melaporkan konflik dokumen atau asumsi, putuskan dulu, ubah `DECISIONS.md` bila perlu, baru lanjutkan.

### Pembuka Standar (tempel di awal setiap sesi)

```
Kamu bekerja di repo SIAKAR (monorepo: mobile/ admin/ ml/ docs/).
Sebelum menulis kode, baca berurutan:
1. AGENTS.md (aturan keras, menang atas kebiasaanmu)
2. docs/project-kit/DECISIONS.md (menang atas dokumen lain)
3. Bagian PRD/DESIGN/API/ML_SPEC yang disebut di tugas, serta skill yang disebut di tugas
Kerjakan HANYA tugas di bawah. Jika tugas bertentangan dengan dokumen, berhenti dan laporkan konfliknya; jangan memilih sendiri.
Jangan mengubah skema DB, kontrak API, atau kontrak model tanpa mengubah dokumennya lebih dulu dan menyebutnya di ringkasan.
Jangan menyatakan selesai sebelum menjalankan verifikasi.
Di akhir, beri ringkasan: (1) apa yang diubah, (2) cara verifikasi dan hasilnya, (3) asumsi yang dibuat, (4) yang belum dikerjakan, (5) langkah uji manual untukku bila perlu perangkat fisik.
```

### Urutan yang disarankan

Jalur **ML** adalah jalur kritis, jadi mulai ML bersamaan dengan fondasi BE dan MOB.

| Tahap | Backend | Mobile | Admin | ML |
|---|---|---|---|---|
| Fondasi | B1, B2 | M1, M2 | — | ML1, ML2, ML3, ML4 |
| Inti | B3, B4, B5 | M3, M4, M5 | A1, A2 | ML5, ML6, ML7 |
| Integrasi | B6 | M6, M7, M8, M9 | A3, A4 | — |
| Akhir | Prompt Z1 (stabilisasi) |  |  |  |

---

## Prompt 0 — Monorepo (T-101)

```
Tugas: T-101. Buat struktur monorepo SIAKAR.
- Buat folder mobile/, admin/, ml/, docs/. Salin AGENTS.md ke root; project-kit ke docs/project-kit/.
- Buat .gitignore yang mengecualikan: ml/data/, ml/.venv/, .env, *.tflite besar yang tidak perlu, vendor/, node_modules/, build/, storage privat, foto/dataset.
- Buat README.md root singkat (struktur folder + cara menjalankan tiap bagian, ambil dari AGENTS.md §4).
Selesai bila: repo bisa di-clone dan strukturnya sesuai DESIGN.md §4. Jangan membuat kode aplikasi apa pun di tugas ini.
```

---

# JALUR BACKEND (Laravel, folder `admin/`)

Baca skill: `laravel-api-endpoint`.

## B1 — Proyek Laravel + skema + seeder (T-111, T-112)

```
Tugas: T-111 dan T-112.
Baca: DECISIONS §4 dan §4.1, DESIGN §4.2 dan §5, skill laravel-api-endpoint.
Kerjakan:
1. Buat proyek Laravel di admin/, koneksi MySQL via .env (sediakan .env.example tanpa rahasia), timezone Asia/Jakarta, pasang Sanctum.
2. Buat migrasi untuk SEMUA tabel di DESIGN §5, persis sesuai nama tabel/kolom (kamus data berbahasa Indonesia, termasuk penyesuaian DECISIONS §4.1).
3. Buat model dengan $table, $primaryKey, $timestamps=false; enum sebagai konstanta.
4. Buat seeder demo: 1 admin, 1 atasan, beberapa karyawan dengan atasan langsung, departemen, jabatan, shift, jadwal, 1-2 lokasi kantor (lat/long + radius), beberapa hari libur.
Jangan membuat endpoint di tugas ini.
Selesai bila: `php artisan migrate --seed` berhasil dari database kosong dan menghasilkan data demo. Tunjukkan hasil `migrate:fresh --seed`.
```

## B2 — Auth + device binding (T-113)

```
Tugas: T-113. Baca API.md §1, §2, §3.1, §4 dan DECISIONS D-60..D-68.
Kerjakan:
1. Kelas ApiResponse (amplop sukses/gagal sesuai API.md §1) dan handler DomainException yang menghasilkan respons gagal seragam dengan kode error bertipe.
2. Endpoint POST /api/v1/auth/login (pengikatan device_id pada login pertama; DEVICE_MISMATCH bila beda), POST /auth/logout, GET /me.
3. Middleware EnsureRole.
4. Password bcrypt, token Sanctum. Jangan log password/token.
Tes Feature: login sukses, kredensial salah, perangkat beda, logout, /me tanpa token (401), semua kode error yang relevan di API.md §1.
Selesai bila: `php artisan test` lulus untuk auth.
```

## B3 — Service Haversine dan cosine (T-211)

```
Tugas: T-211. Baca API.md §3.3 (urutan pemeriksaan) dan PRD §5 aturan 2 dan 6.
Kerjakan GeofenceService (Haversine ke tiap lokasi_kantor; lolos bila ada lokasi dengan jarak <= radius_meter; kembalikan lokasi terdekat yang lolos beserta jaraknya) dan FaceMatchService (cosine similarity antara embedding masuk dan embedding terdaftar; ambang dibaca dari config/face.php).
Buat config/face.php dengan ambang sementara yang jelas ditandai "akan diganti dari ml/artifacts/threshold.json".
Tes Unit: Haversine dengan jarak yang diketahui (termasuk tepat di batas radius), cosine dengan vektor yang diketahui (identik = 1, ortogonal = 0).
Selesai bila: tes unit lulus. Jangan membuat endpoint di tugas ini.
```

## B4 — Registrasi wajah di server (T-212)

```
Tugas: T-212. Baca API.md §3.2, DESIGN §3 (sequence registrasi wajah), PRD §4.1 dan kriteria FR-02, DECISIONS (keputusan enkripsi embedding).
Kerjakan POST /face/enroll dan GET /face/status:
- Terima 3-5 embedding dari klien (+ foto), rata-ratakan, L2-normalisasi, ENKRIPSI sebelum simpan.
- Foto disimpan di disk privat, bukan publik.
- Perbarui data wajah: embedding lama diganti hanya setelah registrasi baru berhasil (transaksi).
- Jangan pernah mengembalikan embedding di respons atau mencatatnya di log.
Tes Feature: enroll sukses, jumlah foto kurang, perbarui, status sebelum/sesudah enroll, akses tanpa peran.
Selesai bila: `php artisan test` lulus; tunjukkan bahwa embedding di DB terenkripsi.
```

## B5 — Absensi masuk/pulang/riwayat (T-213)

```
Tugas: T-213. Baca API.md §3.3 (IKUTI URUTAN PEMERIKSAAN PERSIS), PRD §5 (semua aturan), PRD §6 kriteria FR-03/FR-04.
Kerjakan GET /attendance/today, POST /attendance/check-in, POST /attendance/check-out, GET /attendance/history.
Aturan wajib:
- Waktu = waktu server (WIB); abaikan waktu dari klien.
- Status terlambat bila waktu_absen > shift.jam_masuk + toleransi_menit; selain itu hadir.
- Tolak: tidak ada jadwal, hari libur, DEVICE_MISMATCH, OUT_OF_RADIUS, FACE_MISMATCH, ALREADY_CHECKED_IN, pulang tanpa masuk.
- Maksimal satu baris absensi per karyawan per tanggal. Percobaan gagal TIDAK menyimpan baris absensi.
- Simpan id_lokasi terdekat yang lolos, jarak, skor cosine, foto bukti (disk privat).
- Jangan mengembalikan embedding.
Tes: Unit untuk status hadir/terlambat tepat di batas toleransi; Feature untuk jalur sukses dan SETIAP kode error.
Selesai bila: `php artisan test` lulus dan seluruh kode error API.md §1 yang relevan teruji.
```

## B6 — Izin, persetujuan, rekap tim (T-311)

```
Tugas: T-311. Baca API.md §3.4 dan §3.5, PRD §4.3 dan kriteria FR-06/FR-07/FR-08.
Kerjakan /leaves (ajukan, daftar status, lampiran), /approvals (daftar menunggu, setuju/tolak), /team/recap.
Aturan: hanya atasan langsung pemohon yang boleh memutuskan (selain itu 403). Saat disetujui, dalam SATU transaksi DB: ubah status, isi id_penyetuju, dan catat status izin/sakit/cuti pada baris absensi untuk setiap tanggal dalam rentang.
Tes Feature: ajukan, setuju, tolak, bukan atasan langsung (403), rentang tanggal tercatat, rollback bila gagal di tengah.
Selesai bila: `php artisan test` lulus.
```

---

# JALUR MOBILE (Flutter, folder `mobile/`)

Baca skill: `flutter-clean-feature` (dan `ml-train-evaluate-export` untuk M3).

## M1 — Proyek Flutter, arsitektur, tema (T-121)

```
Tugas: T-121. Baca DESIGN §4.1 (struktur), §6 (design token), §7 (komponen bersama), skill flutter-clean-feature.
Kerjakan:
1. Proyek Flutter di mobile/ (target Android) dengan struktur Clean Architecture sesuai DESIGN §4.1.
2. DI dengan get_it, routing go_router, state Cubit.
3. Tema dari design token di DESIGN §6 (warna, tipografi, radius) di folder design/, plus widget bersama PrimaryButton dan StatusBadge.
4. core/error dengan kelas Failure bertipe.
5. Layar Login (tampilan saja, belum terhubung API) dengan tema tersebut. Teks bahasa Indonesia, target sentuh >= 48 px.
Selesai bila: `flutter analyze` bersih dan `flutter run` menampilkan layar login bertema.
```

## M2 — Dio client + Login terhubung API (T-122)

```
Tugas: T-122. Baca API.md §1, §3.1, §5 dan skill flutter-clean-feature.
Kerjakan Dio client (base URL dari konfigurasi), interceptor token Sanctum, pemetaan kode error API -> Failure -> pesan UI HANYA di core/error/. Hubungkan layar Login ke /auth/login, /auth/logout, /me; kirim device_id; simpan token dengan secure storage.
Larangan: jangan retry otomatis, jangan mengirim waktu klien.
Tes: unit test UseCase (repository di-mock) dan Cubit.
Selesai bila: login berhasil terhadap API lokal, dan kegagalan (salah password, DEVICE_MISMATCH, tanpa jaringan) menampilkan pesan Indonesia yang benar. Tulis langkah uji manual untukku.
```

## M3 — Praproses Dart + embedding TFLite + tes paritas (T-221)

```
Tugas: T-221. Ini bagian paling berisiko; kerjakan dengan uji kecil lebih dulu.
Baca ML_SPEC.md §4 (kontrak praproses), §5 (kontrak ekspor), AGENTS aturan 4, ml/artifacts/preprocess.json, skill flutter-clean-feature dan ml-train-evaluate-export.
Kerjakan:
1. core/ml/preprocess di Dart yang mengikuti preprocess.json PERSIS (jangan membuat variasi sendiri).
2. embedding_service yang memuat siakar_embedding.tflite dari assets/models/ dan menghasilkan vektor [1,128] L2-normalized.
3. Tes paritas memakai golden vectors dari Python: cosine(embedding Dart, referensi) >= 0.99.
Jika golden vectors/model belum ada, berhenti dan laporkan; jangan memalsukan.
Selesai bila: tes paritas lulus. Jelaskan cara menjalankannya.
```

## M4 — Kamera, oval panduan, GPS, izin (T-222)

```
Tugas: T-222. Baca DESIGN §9 (aturan antarmuka kamera/oval), §8.1, PRD §4.2.
Kerjakan komponen kamera dengan oval panduan, pengambilan foto, GPS (geolocator), dan permintaan izin yang kontekstual (jelaskan alasan sebelum meminta izin, tangani ditolak/ditolak permanen dengan arahan ke pengaturan).
Jangan menghubungkan ke API di tugas ini.
Selesai bila: berjalan di ponsel asli. Tuliskan langkah uji manual (izin diterima, ditolak, GPS mati).
```

## M5 — Registrasi wajah end-to-end (T-223)

```
Tugas: T-223. Baca PRD §4.1, kriteria FR-02, API.md §3.2, DESIGN §3.
Kerjakan alur: menu Registrasi Wajah -> kamera + oval -> ambil 3-5 foto (depan, sedikit kiri/kanan) -> validasi wajah dalam oval -> praproses + embedding di perangkat (M3) -> kirim ke POST /face/enroll -> konfirmasi. Sediakan opsi Perbarui bila sudah terdaftar. Menu Absen terkunci sampai wajah terdaftar.
Selesai bila: wajah terdaftar di DB lewat aplikasi (uji di ponsel asli, tuliskan langkahnya). Foto yang tidak memuat wajah di dalam oval harus ditolak.
```

## M6 — Absen masuk/pulang end-to-end (T-301)

```
Tugas: T-301. Baca PRD §4.2, kriteria FR-03/FR-04, API.md §3.3, DESIGN §2 (flowchart absen masuk).
Kerjakan: Beranda -> Absen Masuk/Pulang -> GPS -> kamera + oval -> validasi wajah -> embedding di perangkat -> kirim embedding + GPS + foto bukti ke API -> tampilkan hasil (status, jam, jarak, skor) atau pesan error ramah per kode error.
Larangan: klien TIDAK menentukan status/radius/ambang, TIDAK mengirim waktu, TIDAK retry otomatis.
Selesai bila skenario demo PRD §8 nomor 3, 4, 5 dapat dijalankan (hadir/terlambat, di luar radius ditolak, wajah lain ditolak). Tuliskan langkah uji manual.
```

## M7 — Beranda, Riwayat, Profil (T-302)

```
Tugas: T-302. Baca PRD kriteria FR-05, API.md §3.3 (today, history), DESIGN §8.1.
Kerjakan layar Beranda (status absen hari ini, tombol Absen), Riwayat (daftar dengan paginasi/filter periode, StatusBadge), Profil (data diri, tombol Perbarui Wajah, Logout).
Selesai bila FR-05 memenuhi kriteria penerimaan. Sertakan tes Cubit.
```

## M8 — Detektor wajah + liveness L1 (T-303)

```
Tugas: T-303. Prasyarat: model detektor (ML7) sudah diekspor. Baca ML_SPEC §3.3, §3.4, DECISIONS D-27, PRD kriteria ML-02/ML-03.
Kerjakan: integrasikan detektor wajah TFLite buatan sendiri ke kamera (validasi wajah di dalam oval, bukan ML Kit) dan liveness L1 challenge-response (mis. perintah menoleh/instruksi acak). Absen harus menolak bila detektor atau liveness gagal.
Larangan keras: tidak boleh memakai ML Kit atau model pihak ketiga (AGENTS aturan 1).
Selesai bila: wajah tidak di oval atau challenge gagal -> absen ditolak di klien. Tuliskan langkah uji manual.
```

## M9 — Izin, persetujuan, rekap (T-321)

```
Tugas: T-321. Baca PRD §4.3, kriteria FR-06/07/08, API.md §3.4 dan §3.5, DESIGN §8.1 (tab tambahan untuk peran atasan).
Kerjakan: (karyawan) form pengajuan izin/sakit/cuti + lampiran dan daftar status; (atasan) tab Persetujuan (setuju/tolak) dan Rekap bawahan. Tab atasan hanya muncul untuk peran atasan.
Selesai bila FR-06/07/08 berjalan terhadap API lokal. Sertakan tes Cubit/UseCase.
```

---

# JALUR ADMIN (Laravel Blade)

Baca skill: `laravel-admin-crud-blade`. Dilarang memakai Filament atau paket panel admin.

## A1 — Layout Blade + komponen + login admin (T-231)

```
Tugas: T-231. Baca DESIGN §6, §7, §8.2, skill laravel-admin-crud-blade.
Kerjakan: Tailwind dengan token dari DESIGN §6 di tailwind.config.js, layouts/admin.blade.php (sidebar navy, konten krem), komponen x-card, x-table, x-form-field, x-status-badge, x-button, halaman login admin, dasbor kosong. Route /admin dengan middleware auth + EnsureRole:admin.
Selesai bila: halaman login dan dasbor kosong bertema; non-admin ditolak. Tes Feature untuk akses.
```

## A2 — CRUD karyawan, departemen, jabatan (T-232)

```
Tugas: T-232. Baca DESIGN §8.2, PRD FR-10, skill laravel-admin-crud-blade.
Kerjakan CRUD karyawan (pencarian + paginasi, atasan langsung, peran), departemen, jabatan; nonaktifkan (bukan hapus); aksi POST terpisah untuk reset wajah dan reset perangkat dengan konfirmasi. Jangan tampilkan embedding.
Selesai bila bisa tambah/ubah/nonaktifkan dan reset wajah/perangkat. Tes Feature: akses, validasi, operasi utama.
```

## A3 — Shift, jadwal, lokasi, hari libur (T-331)

```
Tugas: T-331. Baca PRD FR-10/FR-11, DESIGN §8.2, skill laravel-admin-crud-blade.
Kerjakan CRUD shift (jam masuk/pulang, toleransi_menit), jadwal karyawan, lokasi kantor (lat/long + radius_meter), dan hari libur.
Selesai bila: setelah admin mengubah shift/lokasi/jadwal, absensi berikutnya lewat API memakai nilai baru (buktikan dengan tes).
```

## A4 — Koreksi absensi, rekap, CSV (T-332)

```
Tugas: T-332. Baca PRD FR-12/13/14, DESIGN §8.2.
Kerjakan: koreksi absensi (kolom keterangan WAJIB, jejak perubahan tercatat), rekap per periode (jumlah hadir, terlambat, izin/sakit/cuti, alpa per karyawan) dengan filter, dan ekspor CSV. Foto bukti hanya lewat route ber-otorisasi. Gunakan service yang sama dengan API, jangan menduplikasi aturan bisnis.
Selesai bila FR-12/13/14 berjalan; tes Feature untuk keterangan wajib dan isi CSV.
```

---

# JALUR ML (Python lokal, folder `ml/`)

Baca skill: `ml-train-evaluate-export`. Aturan keras: tanpa bobot pretrained, tanpa model pihak ketiga, tanpa Colab; CPU, RAM 8 GB, jangan memuat seluruh dataset ke memori.

## ML1 — Environment + praproses (T-102, T-104)

```
Tugas: T-102 dan T-104. Baca ML_SPEC §0, §1, §4.
1. Siapkan venv + requirements.txt. Cek tabel kompatibilitas resmi versi Python vs TensorFlow SEBELUM memasang; catat versi di ml/README.md.
2. Tulis src/siakar_ml/preprocess.py, ml/artifacts/preprocess.json, dan tes unit. HANYA satu fungsi praproses.
Selesai bila: `python -c "import tensorflow"` jalan dan tes praproses lulus.
```

## ML2 — Split per identitas + pasangan verifikasi (T-105)

```
Tugas: T-105. Baca ML_SPEC §2.2 dan §6.2.
Buat skrip split per identitas (kelompok A/B/C, seed dikunci) dan pasangan verifikasi tetap, simpan split.json, pairs_val.json, pairs_test.json.
Tes: tidak ada identitas yang sama di dua kelompok; hasil identik antar-run.
Prasyarat: subset DigiFace-1M ada di ml/data/raw/ dan lisensinya dicatat di ml/README.md (T-103). Jika belum, berhenti dan laporkan.
```

## ML3 — Baseline klasik HOG/LBP (T-106)

```
Tugas: T-106. Baca ML_SPEC §3.2 dan §6.
Implementasikan baseline HOG/LBP + evaluasi (klasifikasi dan verifikasi: FAR, FRR, EER, ROC AUC, TAR@FAR). Simpan tabel metrik (CSV) dan grafik (PNG) ke ml/reports/ sejak awal sebagai acuan.
Selesai bila tabel metrik baseline tersimpan. Jangan mengatur ulang hyperparameter berdasarkan data uji.
```

## ML4 — Uji 1 epoch (T-107)

```
Tugas: T-107. Baca ML_SPEC §3.1 dan §2.
Latih CNN embedding dari nol SATU epoch pada subset kecil. Ukur waktu per epoch. Dengan hasil itu usulkan n_identities dan ukuran input (jelaskan perhitungannya). tf.data baca dari disk dengan prefetch.
Selesai bila waktu per epoch tercatat dan usulan n_identities/ukuran input ditulis. Jangan latihan penuh di tugas ini; keputusan akhir ada di tanganku.
```

## ML5 — Latih model penuh + evaluasi (T-201, T-202, T-203)

```
Tugas: T-201 sampai T-203. Baca ML_SPEC §3.1, §2.3, §6.
Arsitektur CNN embedding (keluaran 128-d, L2-normalized) + pipeline tf.data + augmentasi hanya pada data latih; checkpoint tiap epoch; early stopping. Evaluasi sesuai §6 (klasifikasi set tertutup dan verifikasi identitas baru), 2-3 ablasi, dan tulis analysis.md (perbandingan vs baseline, mengapa hasilnya begitu, keterbatasan selisih domain sintetis -> nyata).
Larangan: jangan mengklaim akurasi pada wajah nyata; ambang dipilih di validasi, bukan di data uji.
Selesai bila metrik + kurva ada di ml/reports/ dan analysis.md memuat perbandingan.
```

## ML6 — Ekspor TFLite + paritas + golden vectors (T-204)

```
Tugas: T-204 (jangan ditunda). Baca ML_SPEC §5 dan §7, skill ml-train-evaluate-export langkah 7-9.
Ekspor siakar_embedding.tflite TANPA kepala softmax (keluaran [1,128] L2-normalized), uji paritas Keras vs TFLite (cosine >= 0.999), simpan golden vectors, hitung ambang di pasangan validasi -> ml/artifacts/threshold.json, lalu salin artefak ke mobile/assets/models/.
Selesai bila paritas lulus dan semua artefak tersedia. Jangan mengubah kontrak input/output tanpa memperbarui ML_SPEC §5 dan preprocess.json.
```

## ML7 — Detektor wajah (T-108, T-205)

```
Tugas: T-108 dan T-205. Baca ML_SPEC §3.3 dan DECISIONS (Q-2).
Cari sumber data non-wajah (untuk negatif) dan catat lisensinya, lalu latih detektor wajah buatan sendiri (bukan pretrained, bukan ML Kit/Haar bawaan OpenCV), evaluasi, ekspor .tflite.
Selesai bila daftar sumber + lisensi tercatat, metrik detektor tersimpan, dan model .tflite dihasilkan.
```

---

## Prompt Z1 — Stabilisasi dan gladi demo (T-401, T-402)

```
Tugas: T-401 dan T-402. Fitur dibekukan: DILARANG menambah fitur.
Telusuri alur lengkap PRD §8 (skenario demo 1-8) terhadap kode. Untuk setiap skenario, laporkan: lolos / gagal / tidak dapat diuji tanpa perangkat, beserta bug yang ditemukan dan perbaikan minimal. Jalankan `flutter analyze`, `flutter test`, `php artisan test`, `pytest`. Buat daftar langkah gladi manual untukku, termasuk rencana bila akurasi kamera nyata rendah (PRD §8 paragraf terakhir).
```

---

## Tips agar AI tetap terarah

- **Satu sesi, satu ID tugas.** Jika AI mulai menambah fitur lain, hentikan dan ingatkan batasnya.
- **Minta rencana dulu untuk tugas berisiko** (M3, M4, M8, ML6): tambahkan di akhir prompt, "Sebelum menulis kode, tuliskan rencana singkatmu dan tunggu persetujuanku."
- **Jika AI menemukan konflik atau menebak**, minta ia mencatat asumsi; keputusan yang berubah ditulis ke `DECISIONS.md` lebih dulu.
- **Tugas yang butuh perangkat fisik** (kamera, GPS) tidak bisa diverifikasi AI; selalu minta langkah uji manual dan jalankan sendiri.
- **Commit setelah tiap prompt lolos verifikasi**, supaya mudah mundur bila sesi berikutnya merusak sesuatu.
