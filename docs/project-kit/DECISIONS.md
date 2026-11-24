# DECISIONS.md — Keputusan Proyek SIAKAR

> Sumber kebenaran tunggal. Dokumen lain (PRD, DESIGN, API, ML_SPEC, AGENTS, TASKS) **harus** mengikuti file ini.
> Jika ada konflik, file ini menang. Jika keputusan berubah, ubah file ini **dulu**, lalu sinkronkan dokumen lain.

Label status:

- **[FIXED]**: sudah diputuskan oleh kelompok atau dosen. Jangan diubah tanpa persetujuan kelompok.
- **[PROPOSED]**: usulan default. Dipakai sampai ada koreksi dari kelompok.
- **[OPEN]**: belum diputuskan. Jangan diasumsikan; tanyakan atau pilih opsi aman sesuai catatan.

Nama proyek: **SIAKAR** — Sistem Absensi Karyawan Berbasis Mobile dengan Face Recognition.
Konteks: proyek akhir lintas mata kuliah (MPPL, Pemrograman Mobile 2, Kecerdasan Buatan). Mata kuliah Visi Komputer memakai proyek terpisah dan **di luar lingkup** repo ini.
Waktu pengerjaan: sekitar 1 bulan; analisis sistem (laporan MPPL) sudah selesai.

---

## 1. Keputusan Teknis

| ID   | Keputusan                                                                                                                           | Status   | Catatan                                                                       |
| ---- | ----------------------------------------------------------------------------------------------------------------------------------- | -------- | ----------------------------------------------------------------------------- |
| D-01 | Semua pengerjaan (aplikasi, admin, pelatihan model) dalam **satu repositori dan satu code editor**. **Google Colab tidak dipakai.** | FIXED    | Aturan dosen: kurangi jumlah platform                                         |
| D-02 | Struktur monorepo: `mobile/` (Flutter), `admin/` (Laravel), `ml/` (Python), `docs/`                                                 | PROPOSED | Lihat AGENTS.md                                                               |
| D-03 | Mobile: **Flutter + Dart**, **Clean Architecture**, state management **Cubit** (`flutter_bloc`)                                     | FIXED    |                                                                               |
| D-04 | Backend: **Laravel** (REST API untuk mobile + web admin)                                                                            | FIXED    |                                                                               |
| D-05 | Basis data: **MySQL**                                                                                                               | FIXED    | Kamus data laporan sudah bertipe MySQL                                        |
| D-06 | Admin/HRD: **Laravel web dengan Blade** (bukan Filament, bukan Flutter web)                                                         | FIXED    | UI/UX mengikuti aplikasi Flutter lewat design token bersama (lihat DESIGN.md) |
| D-07 | CSS admin: **Tailwind CSS** dengan token warna/tipografi yang sama dengan Flutter                                                   | PROPOSED | Alternatif: CSS variable biasa bila setup Tailwind menyita waktu              |
| D-08 | Platform target: **Android** dulu; build iOS tidak ditargetkan                                                                      | PROPOSED |                                                                               |
| D-09 | Zona waktu aplikasi dan MySQL: **Asia/Jakarta (WIB)**                                                                               | PROPOSED | Penting untuk status Terlambat                                                |
| D-10 | Autentikasi mobile: **Laravel Sanctum** (token). Admin web: sesi (guard `web`)                                                      | PROPOSED | Model akun memakai tabel `pengguna`, bukan `users`                            |

## 2. Keputusan AI / Model

| ID   | Keputusan                                                                                                                                                                                     | Status                               | Catatan                                                                                                |
| ---- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------ | ------------------------------------------------------------------------------------------------------ |
| D-20 | Model pengenalan wajah **dibangun dan dilatih dari nol** (tanpa bobot pretrained apa pun). Syarat dosen AI dan Visi Komputer.                                                                 | FIXED                                | Dilarang memakai ArcFace/FaceNet/MobileNet pretrained, ML Kit, InsightFace, DeepFace, dll              |
| D-21 | Pelatihan di **Python** (editor yang sama dengan proyek), tanpa Colab. Framework: **TensorFlow/Keras**                                                                                        | FIXED (Python) / PROPOSED (TF-Keras) | Dipilih agar ekspor ke TFLite mudah                                                                    |
| D-22 | Arsitektur: **CNN kecil dengan lapisan embedding**; dilatih sebagai classifier, embedding diambil dari lapisan sebelum output                                                                 | FIXED                                | Detail di ML_SPEC.md                                                                                   |
| D-23 | **Detektor wajah dan liveness juga dibuat sendiri** (dari nol)                                                                                                                                | FIXED                                | Prioritas pengerjaan: embedding, lalu detektor, lalu liveness (D-26)                                   |
| D-24 | Definisi akurasi mencakup **klasifikasi** dan **verifikasi** (identitas baru). Batasan proyek menentukan target                                                                               | FIXED                                | Dosen AI toleran terhadap angka akhir, wajib ada hasil dan analisis                                    |
| D-25 | Target akurasi internal                                                                                                                                                                       | OPEN                                 | Tetapkan setelah baseline selesai. Jangan menulis angka target di laporan sebagai klaim sebelum diukur |
| D-26 | Urutan prioritas: **(1) model embedding → (2) detektor wajah → (3) liveness**                                                                                                                 | PROPOSED                             | Jika waktu habis, liveness diperkecil (D-27)                                                           |
| D-27 | Fallback liveness bila model liveness tidak selesai: **challenge-response tanpa model** (mis. perintah gerak wajah yang diukur dari perubahan posisi kotak detektor), dicatat sebagai batasan | OPEN                                 | Perlu konfirmasi dosen apakah dapat diterima                                                           |
| D-28 | Inferensi embedding **di perangkat** (model `.tflite` di aplikasi, paket `tflite_flutter`); **pencocokan (cosine similarity) di Laravel**                                                     | PROPOSED                             | Tidak ada runtime Python saat aplikasi berjalan                                                        |
| D-29 | Pendekatan tanpa penyelarasan (alignment-free): tampilan kamera memakai oval panduan, dan augmentasi pelatihan memasukkan variasi rotasi/skala/geser                                          | PROPOSED                             | Tidak ada model landmark. Lihat risiko R-03                                                            |
| D-30 | Baseline klasik sebagai pembanding: **HOG atau LBP + cosine/SVM** (scikit-image / scikit-learn)                                                                                               | PROPOSED                             | Untuk bagian hasil dan analisis                                                                        |
| D-31 | Ambang kecocokan **tidak di-hardcode**. Dipilih dari validasi data (EER atau target FAR) dan disimpan di `config/face.php` (env override)                                                     | PROPOSED                             |                                                                                                        |
| D-32 | **Kontrak numerik praproses lintas bahasa (Python ↔ Dart):** (1) crop kotak oval memakai pembulatan indeks `floor`, (2) resize memakai **bilinear murni** (`coordinate_transformation_mode = half_pixel`, `border_mode = clamp_to_edge`, **`anti_aliasing = false`** — tanpa filter Gaussian maupun *reflect padding*), (3) konversi hasil interpolasi ke `uint8` memakai pembulatan eksplisit **`floor(clamp(v, 0, 255) + 0.5)`** (`floor_half_up`, bukan pemotongan `int(v)` dan bukan *round-half-to-even*), lalu (4) normalisasi `float32` `(float32(u8) - 127.5) / 127.5` dalam `[-1, 1]` urutan RGB | FIXED | Ditetapkan sebelum latihan penuh ML5–ML7 agar paritas numerik Python (`preprocess.py` & `tf.data`) ↔ Dart (`M3`) terjamin identik |

## 3. Keputusan Data

| ID   | Keputusan                                                                                                                                                                                                                                                                                                                                                                                                                                                                                  | Status   | Catatan                                                                                                                        |
| ---- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | -------- | ------------------------------------------------------------------------------------------------------------------------------ |
| D-40 | Dataset **sintetis saja**; tidak ada foto nyata yang disimpan atau dilatih                                                                                                                                                                                                                                                                                                                                                                                                                 | FIXED    | Dikonfirmasi dosen                                                                                                             |
| D-41 | Dataset latih utama: **DigiFace-1M** (Microsoft; 10 ribu identitas × 72 gambar, potongan 112×112)                                                                                                                                                                                                                                                                                                                                                                                          | PROPOSED | Baca `LICENSE` di repo resminya, lisensi non-komersial riset. Cantumkan sitasi paper                                           |
| D-42 | Dataset uji tambahan (opsional): SynMulti-PIE (Idiap)                                                                                                                                                                                                                                                                                                                                                                                                                                      | PROPOSED | Lisensi belum diperiksa                                                                                                        |
| D-43 | Hindari dataset sintetis turunan generator yang dilatih dari data wajah nyata yang ditarik (mis. DCFace/GANDiffFace)                                                                                                                                                                                                                                                                                                                                                                       | PROPOSED | Risiko kebocoran identitas nyata                                                                                               |
| D-44 | Data **non-wajah** (detektor): (1) citra non-wajah prosedural sintetis bawaan (`prepare_negatives.py`, internal proyek) + potongan latar DigiFace di luar wajah, (2) opsional tekstur murni tanpa manusia **DTD (Describable Textures Dataset, Cimpoi et al., CVPR 2014 — lisensi riset akademik)** atau **FractalDB (CC BY 4.0)**. Data **liveness**: tidak diperlukan pada Level L1 (_challenge-response_ berbasis perubahan skor & kotak `[cx, cy, w, h]` detektor antar-frame, `D-27`) | PROPOSED | Tetap patuh `D-40` (tanpa foto wajah manusia nyata); sitasi & lisensi dicatat di `ml/README.md`                                |
| D-45 | Pemisahan data **per identitas** untuk uji verifikasi, dan per set aksesori/sesi untuk uji klasifikasi. Seed acak dikunci                                                                                                                                                                                                                                                                                                                                                                  | PROPOSED | Mencegah kebocoran data                                                                                                        |
| D-46 | Jumlah identitas subset (`n_identities = 500`), ukuran input (`input_size = 112`), `batch_size = 32`, `epochs = 30` (dengan _early stopping_)                                                                                                                                                                                                                                                                                                                                              | PROPOSED | Opsi aman default sesuai Q-3 & kontrak `preprocess.json`; perbarui ke FIXED di §3.1 bila angka benchmark aktual laptop berbeda |

### 3.1 Pencatatan Hasil Benchmark 1 Epoch & Keputusan Hyperparameter Final (D-46 / T-107)

> Catatan: Karena angka waktu aktual dari eksekusi manual `benchmark_epoch.py` belum dimasukkan pada prompt sesi ML5/ML6, proyek memakai **opsi aman tertulis (`PROPOSED`)** sesuai `DECISIONS.md` Q-3 dan `ML_SPEC.md` §2.1/§3.1 tanpa memalsukan angka waktu benchmark. Jika setelah menjalankan `benchmark_epoch.py` waktu per epoch di laptop terlalu tinggi, ubah `n_identities` atau `input_size` di sini terlebih dahulu lalu di `ml/configs/embedding.yaml` (serta `preprocess.json` bila `input_size` berubah).

| Parameter / Pengukuran                | Nilai Keputusan / Hasil Benchmark                                                                                      | Catatan                                               |
| ------------------------------------- | ---------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------- |
| Perangkat uji (CPU & RAM)             | Laptop CPU lokal (tanpa GPU, target RAM ≤ 8 GB)                                                                        | Sesuai `ML_SPEC.md` §0.2                              |
| Konfigurasi acuan                     | `n_identities=500`, `input_size=112`, `batch_size=32`                                                                  | Sumber: `ml/configs/embedding.yaml`                   |
| Waktu 1 epoch aktual (wall-clock)     | _(belum diisi — jalankan manual `benchmark_epoch.py`)_                                                                 | Otomatis tertulis ke `ml/reports/benchmark_1epoch.md` |
| Kecepatan steady-state                | _(belum diisi — jalankan manual `benchmark_epoch.py`)_                                                                 | Otomatis tertulis ke `ml/reports/benchmark_1epoch.md` |
| Puncak penggunaan RAM proses          | _(belum diisi — jalankan manual `benchmark_epoch.py`)_                                                                 | Otomatis tertulis ke `ml/reports/benchmark_1epoch.md` |
| **Keputusan `n_identities`**          | **`500` [PROPOSED]** (A=350 latih, B=75 validasi, C=75 uji)                                                            | Sesuai opsi aman Q-3 (`ML_SPEC.md` §2.1)              |
| **Keputusan `input_size`**            | **`112` [PROPOSED]** (`[112, 112, 3]` RGB `[-1, 1]`)                                                                   | Selaras penuh dengan `preprocess.json` & mobile       |
| **Keputusan `batch_size` & `epochs`** | **`batch_size=32`, `epochs=30`** (`early_stopping_patience=8`)                                                         | Checkpoint disimpan tiap epoch; `ReduceLROnPlateau`   |
| **Skenario ablasi (`T-203`)**         | (1) Default (`aug=on, dim=128, softmax`), (2) Tanpa augmentasi (`aug=off`), (3) `embedding_dim=64` atau `head=cosface` | Sesuai `ML_SPEC.md` §6.3                              |

## 4. Keputusan Fungsional dan Data Aplikasi

| ID   | Keputusan                                                                                                                                                                       | Status   |
| ---- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------- |
| D-60 | **Server adalah otoritas**: waktu (server), geofencing, shift, hari libur, status Hadir/Terlambat, dan ambang kecocokan semuanya dihitung/diputuskan di Laravel, bukan di klien | PROPOSED |
| D-61 | Geofencing: rumus **Haversine**; lokasi yang dipakai = lokasi kantor terdekat yang radiusnya mencakup titik GPS; bila tidak ada → `OUT_OF_RADIUS`                               | PROPOSED |
| D-62 | Status: `terlambat` bila jam absen masuk > `shift.jam_masuk + toleransi_menit`, selain itu `hadir`                                                                              | PROPOSED |
| D-63 | Tidak ada jadwal pada tanggal tersebut → absen ditolak (`NO_SCHEDULE`). Hari libur → ditolak (`HOLIDAY`)                                                                        | PROPOSED |
| D-64 | Satu karyawan maksimal **satu baris absensi per tanggal** (unique `id_karyawan + tanggal`); absen pulang melengkapi baris yang sama                                             | PROPOSED |
| D-65 | Registrasi wajah: ambil **3–5 foto**, hitung embedding tiap foto, server merata-ratakan lalu **L2-normalize** → satu embedding per karyawan di `data_wajah`                     | PROPOSED |
| D-66 | Embedding disimpan **terenkripsi** (`Crypt` Laravel) sebagai BLOB/teks. Foto referensi disimpan di disk privat                                                                  | PROPOSED |
| D-67 | Pengikatan perangkat: `pengguna.device_id` terisi saat login pertama; perangkat lain ditolak (`DEVICE_MISMATCH`); admin dapat mereset                                           | PROPOSED |
| D-68 | Persetujuan izin hanya oleh **atasan langsung** pemohon (`karyawan.id_atasan`). Setelah disetujui, sistem mencatat status izin/sakit/cuti pada rentang tanggal terkait          | PROPOSED |
| D-69 | Ekspor laporan: **CSV** dulu; PDF/Excel hanya bila waktu tersisa                                                                                                                | PROPOSED |
| D-70 | Antarmuka berbahasa **Indonesia**                                                                                                                                               | PROPOSED |

### 4.1 Penyesuaian skema dari kamus data laporan (perlu disetujui)

Kamus data di laporan analisis adalah acuan. Penyesuaian di bawah ini dibutuhkan agar fungsi di atas berjalan. Semuanya **PROPOSED**:

1. `absensi.id_shift`, `id_lokasi`, `jam_masuk`, `jam_pulang`, `lat_*`, `long_*`, `foto_*`, `skor_wajah` dibuat **nullable** (baris izin/sakit/cuti tidak punya data wajah/lokasi).
2. Tambah **UNIQUE** `(id_karyawan, tanggal)` pada `absensi`.
3. Tabel tanpa `created_at/updated_at`; model Eloquent memakai `$timestamps = false`, kecuali ditambahkan bersama migrasi.
4. Bila fitur absen manual (fallback) dikerjakan, tambah `absensi.metode ENUM('wajah','manual') DEFAULT 'wajah'` dan `absensi.id_penyetuju` (nullable, FK `karyawan`). Jika tidak dikerjakan, tidak ada perubahan.
5. Tabel master tambahan di UI admin: `departemen` dan `jabatan` (CRUD kecil, dibutuhkan form karyawan).

## 5. Perubahan terhadap Laporan Analisis (wajib disinkronkan)

Laporan analisis versi sebelumnya masih menyebut arsitektur lama. Perbarui:

| Bagian laporan / PPT               | Isi lama                                                                | Isi baru                                                                                                                                                                                      |
| ---------------------------------- | ----------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 2.4 Teknologi usulan (slide 9 PPT) | MobileFaceNet/FaceNet via TensorFlow Lite; backend Laravel atau Node.js | CNN dibangun dari nol (TensorFlow/Keras) → TFLite di Flutter; backend Laravel; admin Blade                                                                                                    |
| 2.4 Arsitektur                     | pencocokan embedding di sisi aplikasi                                   | embedding dihitung di aplikasi, **pencocokan di Laravel**                                                                                                                                     |
| DFD Level 1/2 (label aliran)       | `foto wajah` dikirim dari Karyawan ke proses 4.x                        | Pada batas sistem, aplikasi mengirim **embedding wajah + GPS + foto bukti**. Ekstraksi embedding terjadi di aplikasi sebelum dikirim. Struktur proses 4.1–4.5 tidak berubah secara konseptual |
| Kamus data                         | sesuai laporan                                                          | tambah penyesuaian pada 4.1 di atas                                                                                                                                                           |
| Daftar pustaka                     | UU PDP, FaceNet, ArcFace                                                | tambah paper DigiFace-1M; FaceNet/ArcFace hanya jadi rujukan teori (bukan model yang dipakai)                                                                                                 |
| 1.4 Batasan purwarupa              | liveness sederhana                                                      | tambah: data sintetis saja, selisih domain ke wajah nyata, embedding dihitung di klien                                                                                                        |

## 6. Pertanyaan Terbuka

| #   | Pertanyaan                                                           | Ke siapa  | Opsi aman sementara                                                                          |
| --- | -------------------------------------------------------------------- | --------- | -------------------------------------------------------------------------------------------- |
| Q-1 | Apakah fallback liveness tanpa model (D-27) dapat diterima?          | Dosen AI  | Kerjakan model liveness terakhir; siapkan fallback                                           |
| Q-2 | Sumber dan lisensi data non-wajah (detektor) dan data liveness       | Tim       | Terjawab di `D-44` & `ml/README.md` (negatif sintetis + opsional DTD/FractalDB; liveness L1) |
| Q-3 | Berapa identitas subset yang muat di laptop?                         | Tim (uji) | Mulai 500 identitas, naikkan bertahap                                                        |
| Q-4 | Target akurasi internal                                              | Tim       | Tetapkan setelah baseline                                                                    |
| Q-5 | Apakah baseline klasik (HOG/LBP) dihitung sebagai bagian "dari nol"? | Dosen AI  | Gunakan sebagai pembanding saja                                                              |
| Q-6 | Apakah absen manual (fallback demo) dikerjakan?                      | Tim       | Could, kerjakan bila fitur Must dan Should selesai                                           |
| Q-7 | Apakah laporan/proposal PM2 mengharuskan admin berbasis Flutter?     | Dosen PM2 | Tetap Blade                                                                                  |

## 7. Risiko Utama

| ID   | Risiko                                                                                           | Mitigasi                                                                                       |
| ---- | ------------------------------------------------------------------------------------------------ | ---------------------------------------------------------------------------------------------- |
| R-01 | Dataset/pelatihan menyita waktu (laptop 8 GB tanpa GPU)                                          | Subset kecil, input boleh diturunkan (112 → 96/64), uji 1 epoch dulu, checkpoint tiap epoch    |
| R-02 | **Selisih domain sintetis → wajah nyata**: akurasi di aplikasi bisa jauh di bawah hasil evaluasi | Augmentasi meniru kamera ponsel; tulis keterbatasan; demo memakai skenario terkontrol          |
| R-03 | Tidak ada alignment/landmark: crop kamera berbeda dari data latih                                | Oval panduan + augmentasi rotasi/skala/geser; uji paritas praproses                            |
| R-04 | Praproses Dart ≠ praproses Python → akurasi hancur di aplikasi                                   | Satu spesifikasi matematis di `ML_SPEC` §4 & `D-32` (bilinear murni `half_pixel` + `clamp_to_edge`, `anti_aliasing=false`, `floor_half_up`); uji paritas golden vectors |
| R-05 | Klien dapat mengirim embedding palsu (pencocokan di server tapi ekstraksi di klien)              | Ikat perangkat, kirim foto bukti, validasi bentuk embedding, rate limit; tulis sebagai batasan |
| R-06 | Konversi TFLite gagal pada lapisan tertentu                                                      | Pakai lapisan standar saja; uji konversi sejak awal, bukan di akhir                            |
| R-07 | Detektor/liveness buatan sendiri kurang andal                                                    | Prioritas terakhir + fallback (D-27)                                                           |
| R-08 | Empat mata kuliah menumpuk dokumen                                                               | Turunkan semua laporan dari PRD dan ML_SPEC; lihat skill `write-report-section`                |
