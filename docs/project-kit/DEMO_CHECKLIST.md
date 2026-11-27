# DEMO_CHECKLIST.md — Verifikasi Akhir & Panduan Gladi Demo SIAKAR (Z1: T-401, T-402)

Dokumen ini merangkum hasil audit stabilisasi akhir (**T-401**) serta urutan langkah gladi bersih 8 skenario demo sesuai **`PRD.md` §8** (**T-402**).

---

## 1. Ringkasan Konsistensi Kontrak & Stabilisasi (T-401)

| Area Pemeriksaan | Nilai / Status | Sumber Kebenaran |
|---|---|---|
| Ambang kecocokan wajah (`FACE_SIMILARITY_THRESHOLD`) | **`0.2167`** (identik SHA-256) | `ml/artifacts/threshold.json` ⇄ `admin/config/face.php` ⇄ `admin/.env.example` ⇄ `mobile/assets/models/threshold.json` |
| Ambang detektor wajah oval | **`0.52`** (identik SHA-256) | `ml/artifacts/detector_threshold.json` ⇄ `mobile/assets/models/detector_threshold.json` ⇄ `DetectorService` |
| Kontrak praproses D-32 (`112×112` & `64×64` detektor) | **Identik SHA-256** (`floor`, bilinear `half_pixel`, `clamp_to_edge`, `floor_half_up`, RGB `[-1, 1]`) | `ml/artifacts/preprocess.json` ⇄ `mobile/assets/models/preprocess.json` |
| Model TFLite (`siakar_embedding.tflite` & `detector.tflite`) | **Identik SHA-256** | `ml/artifacts/*.tflite` ⇄ `mobile/assets/models/*.tflite` |
| Cache driver rate limiter (`throttle:attendance`) | **`CACHE_STORE=file`** (permanen) | Diperbaiki pada `admin/config/cache.php` (default & failover) dan `admin/.env.example` agar tidak memicu HTTP 500 `Table 'siakar.cache' doesn't exist` pada instalasi baru |
| Pengikatan perangkat pada request API | Header **`X-Device-Id`** otomatis | `mobile/lib/core/network/api_client.dart` meneruskan `device_id` tersimpan ke middleware `EnsureDeviceBound` |

---

## 2. Status Audit 8 Skenario Demo (`PRD.md` §8)

| # | Skenario Demo (`PRD.md` §8) | Status Kode & Tes Otomatis | Catatan Perangkat Fisik |
|---|---|---|---|
| **1** | Admin login web, melihat data master dan jadwal | **Lolos** (`AdminAuthAndMasterCrudTest`, `AdminOperationalAndReportTest`) | Dapat dijalankan penuh di browser laptop |
| **2** | Karyawan login, registrasi wajah (3–5 foto di oval) | **Lolos** (`FaceEnrollmentTest`, `m4_m5_..._test.dart`, `m8_..._test.dart`) | Butuh kamera ponsel Android fisik untuk tangkapan nyata |
| **3** | Absen masuk berhasil → `hadir` / `terlambat` | **Lolos** (`AttendanceTest`, `AttendanceStatusUnitTest`, `m6_..._test.dart`) | Butuh kamera + GPS ponsel Android fisik |
| **4** | Absen masuk di luar radius → **ditolak** (`OUT_OF_RADIUS`) | **Lolos** (`GeofenceServiceTest`, `AttendanceTest`, `m6_..._test.dart`) | Uji di ponsel dengan mengatur lokasi kantor jauh dari ruang demo |
| **5** | Wajah berbeda → **ditolak** (`FACE_MISMATCH`) | **Lolos** (`FaceMatchServiceTest`, `AttendanceTest`, `m6_..._test.dart`) | Uji di ponsel dengan wajah anggota tim lain di akun `karyawan1` |
| **6** | Karyawan mengajukan izin → atasan menyetujui → status terlihat | **Lolos** (`LeaveAndApprovalTest`, `m9_leave_and_approval_cubit_test.dart`) | Dapat diuji penuh lewat aplikasi Android / emulator |
| **7** | Admin melihat rekap dan mengunduh CSV | **Lolos** (`AdminOperationalAndReportTest` — header & isi CSV teruji) | Dapat dijalankan penuh di browser laptop |
| **8** | Presentasi hasil evaluasi model (klasifikasi, verifikasi, baseline, keterbatasan) | **Lolos** (`ml/tests/` + artefak `ml/reports/*`) | Menampilkan grafik & tabel evaluasi di `ml/reports/` |

---

## 3. Persiapan Lingkungan & Akun Seeder Demo

### 3.1 Menyalakan Server Backend & Web Admin (Laptop)
Pastikan laptop dan ponsel Android terhubung ke **jaringan Wi-Fi / Hotspot yang sama**.

```powershell
# 1. Cek alamat IPv4 laptop pada jaringan Wi-Fi (misal: 192.168.1.10)
ipconfig

# 2. Siapkan database bersih + data seeder demo & bangun aset CSS Blade
Set-Location admin
php artisan migrate:fresh --seed
php artisan config:clear
npm run build

# 3. Jalankan server agar dapat diakses dari browser laptop DAN ponsel Android
php artisan serve --host=0.0.0.0 --port=8000
```

- URL Web Admin di laptop: `http://127.0.0.1:8000/admin/login`
- URL Base API untuk ponsel fisik: `http://<IP_LAPTOP>:8000/api/v1`

### 3.2 Menjalankan Aplikasi Mobile di Ponsel Android Fisik
Sambungkan ponsel Android dengan *USB Debugging* aktif, lalu jalankan dengan `--dart-define` (tanpa perlu mengubah kode sumber):

```powershell
Set-Location mobile
flutter run --dart-define=API_BASE_URL=http://<IP_LAPTOP>:8000/api/v1
```

*(Jika memakai Emulator Android di laptop yang sama, cukup `flutter run` karena default mengarah ke `http://10.0.2.2:8000/api/v1`.)*

### 3.3 Daftar Akun Seeder (`DatabaseSeeder.php`)

| Username | Password | Nama & NIK | Peran | Kegunaan saat Demo |
|---|---|---|---|---|
| `admin` | `password123` | Budi Santoso (`ADM-001`) | `admin` | Login Web Admin (`/admin/login`) |
| `atasan` | `password123` | Ahmad Fauzi (`ATS-001`) | `atasan` | Login Mobile — menyetujui izin & melihat rekap bawahan (`karyawan1`, `karyawan2`) |
| `karyawan1` | `password123` | Siti Rahmawati (`KRY-001`) | `karyawan` | Login Mobile — registrasi wajah, absen masuk/pulang, ajukan izin |
| `karyawan2` | `password123` | Rizky Pratama (`KRY-002`) | `karyawan` | Akun cadangan karyawan kedua |

> **Penting — Pengikatan Perangkat (`device_id`):** Bila Anda menggunakan **1 ponsel Android yang sama** untuk berganti akun dari `karyawan1` ke `atasan` lalu kembali lagi, akun akan terikat ke ID ponsel tersebut tanpa konflik. Namun jika satu akun ingin dipindah ke ponsel kedua, gunakan tombol **Reset Perangkat** pada menu **Karyawan** di Web Admin.

---

## 4. Urutan Langkah Gladi Demo (Skenario 1–8)

### Skenario 1 — Admin Login Web, Melihat Data Master & Jadwal
1. Buka `http://127.0.0.1:8000/admin/login`, masuk dengan `admin` / `password123`.
2. Tunjukkan menu **Karyawan**, **Departemen**, **Jabatan**, **Shift** (`Reguler 08:00–16:00, toleransi 10 menit`), dan **Jadwal** (otomatis terisi ±15 hari).
3. Buka menu **Lokasi Kantor**:
   - **Sebelum Skenario 3**, ubah koordinat **Kantor Pusat** ke titik GPS ruang presentasi saat ini (mis. ambil dari Google Maps di ruangan, radius `100` meter) agar Skenario 3 berada di dalam radius.
   - Sesuaikan pula **Jam Masuk Shift Reguler** di menu **Shift** (misal atur 30 menit ke depan untuk mendemokan status `HADIR`, atau 30 menit ke belakang untuk mendemokan status `TERLAMBAT`).

### Skenario 2 — Karyawan Login & Registrasi Wajah
1. Di ponsel Android, login sebagai `karyawan1` / `password123`.
2. Tunjukkan bahwa pada **Beranda**, tombol Absen masih terkunci karena wajah belum terdaftar.
3. Tekan **Registrasi Wajah** → baca layar penjelasan izin kamera kontekstual → tekan **Lanjutkan & Izinkan**.
4. Uji penolakan cepat: arahkan kamera ke dinding/meja tanpa wajah lalu tekan **Ambil Foto** → tunjukkan bahwa detektor menolak foto (`FACE_NOT_IN_OVAL`).
5. Posisikan wajah dengan pencahayaan merata di dalam bingkai oval, ambil **3 foto** sesuai panduan (Depan, Sedikit Kiri, Sedikit Kanan) → tekan **Simpan Wajah (3 Foto)**.
6. Setelah muncul **Registrasi Wajah Berhasil**, kembali ke **Beranda** dan tunjukkan bahwa tombol **Absen Masuk** kini aktif.

### Skenario 3 — Absen Masuk Berhasil (`HADIR` / `TERLAMBAT`)
1. Pada **Beranda** `karyawan1`, tekan **Absen Masuk** → setujui penjelasan izin Lokasi GPS kontekstual.
2. Tunjukkan kartu GPS di atas kamera yang menampilkan estimasi jarak ke **Kantor Pusat**.
3. Posisikan wajah lurus di bingkai oval → tekan **Mulai Tantangan Liveness (1/2)**.
4. Ikuti instruksi acak pada **Langkah 2/2** (geser kiri/kanan, angguk naik/turun, atau ubah jarak sedikit tetap di dalam oval) → tekan **Konfirmasi Absen Masuk (2/2)**.
5. Tunjukkan layar **Absen Masuk Berhasil** yang menampilkan badge `HADIR` (atau `TERLAMBAT`), jam server WIB, jarak meter, dan skor kemiripan wajah. Kembali ke **Beranda** (status langsung tersinkronisasi).

### Skenario 4 — Absen Masuk/Pulang di Luar Radius → Ditolak (`OUT_OF_RADIUS`)
1. Di Web Admin (`/admin/lokasi`), ubah sementara koordinat **Kantor Pusat** dan **Kantor Cabang** ke titik yang berjarak > 1 km dari ruang demo (atau gunakan akun `karyawan2` yang baru mendaftarkan wajah).
2. Di ponsel (`karyawan1` tekan **Absen Pulang**, atau `karyawan2` tekan **Absen Masuk**), selesaikan Liveness 1/2 & 2/2.
3. Tunjukkan bahwa klien tetap menyerahkan keputusan ke server, dan server menolak dengan layar **Ditolak (`OUT_OF_RADIUS`)** beserta angka **Jarak Terukur Server**.
4. Kembalikan koordinat **Kantor Pusat** di Web Admin ke lokasi ruang demo.

### Skenario 5 — Wajah Berbeda → Ditolak (`FACE_MISMATCH`)
1. Tetap pada akun `karyawan1` (yang wajahnya terdaftar milik Anggota A).
2. Minta **Anggota B** menghadap kamera oval dan menyelesaikan tantangan Liveness 1/2 & 2/2.
3. Tunjukkan penolakan **Ditolak (`FACE_MISMATCH`)** beserta skor kemiripan kosinus yang berada di bawah ambang `0.2167`.

### Skenario 6 — Pengajuan Izin Karyawan & Persetujuan Atasan
1. Pada akun `karyawan1`, buka tab **Izin** → tekan tombol tambah (**Ajukan Izin**).
2. Pilih jenis (`Izin` / `Sakit` / `Cuti`), pilih rentang tanggal besok s.d. lusa, isi alasan, lalu kirim → tunjukkan status **`MENUNGGU`** pada daftar izin.
3. Buka tab **Profil** → **Keluar Akun**, lalu login sebagai `atasan` / `password123` (`Ahmad Fauzi`).
4. Tunjukkan munculnya tab khusus atasan (**Persetujuan** dan **Rekap**). Buka tab **Persetujuan**, pilih pengajuan `Siti Rahmawati`, lalu tekan **Setujui**.
5. Buka tab **Rekap** pada akun `atasan` (atau login kembali ke `karyawan1` → tab **Izin** / **Riwayat**) untuk menunjukkan status telah berubah menjadi **`DISETUJUI`** dan tercatat pada baris kehadiran tanggal terkait.

### Skenario 7 — Admin Melihat Rekap & Mengunduh CSV
1. Kembali ke Web Admin di browser laptop → buka menu **Absensi** (tunjukkan baris kehadiran `Siti Rahmawati` hari ini dan fitur koreksi dengan keterangan wajib).
2. Buka menu **Laporan Rekap** (`/admin/laporan`), pilih filter bulan berjalan → tunjukkan ringkasan jumlah `Hadir`, `Terlambat`, `Izin/Sakit/Cuti`, dan `Alpa` per karyawan.
3. Klik **Ekspor CSV** dan buka berkas `.csv` yang terunduh untuk menunjukkan kesesuaian isi dengan tabel rekap.

### Skenario 8 — Presentasi Hasil Evaluasi Model AI & Keterbatasan
Buka folder `ml/reports/` untuk memaparkan 4 unsur wajib mata kuliah Kecerdasan Buatan (konsep, kode, hasil, analisis):
- `ml/reports/analysis.md` — analisis lengkap perbandingan CNN dari nol vs Baseline klasik HOG/LBP, hasil studi ablasi, pemilihan ambang validasi `0.2167` (titik EER pada Kelompok B), dan pembahasan selisih domain.
- `ml/reports/baseline_roc_eer.png` & `ml/reports/cnn_roc_eer_main_cnn.png` — kurva ROC dan titik EER.
- `ml/reports/training_curves_main_cnn.png` & `ml/reports/ablation_comparison.csv` — kurva konvergensi latihan dan tabel ablasi.
- `ml/reports/detector_metrics.csv` — F1 (`0.9958`), presisi, recall, dan IoU detektor wajah oval `64×64`.

---

## 5. Rencana Kontingensi Selisih Domain Sintetis → Kamera Nyata (`PRD.md` §8 & `R-02`)

Karena seluruh pelatihan model wajib memakai data 100% sintetis **DigiFace-1M** tanpa bobot pretrained (`D-20`, `D-40`), terdapat selisih domain (*domain gap*) alami terhadap sensor kamera ponsel dan kondisi lampu ruangan nyata:

1. **Praktik Terbaik Saat Gladi & Demo**:
   - Gunakan ruangan bercahaya depan merata (hindari *backlight* jendela terang tepat di belakang kepala).
   - Pastikan saat mendaftarkan wajah (Skenario 2) dan saat absen (Skenario 3), jarak wajah mengisi sekitar 65–80% tinggi bingkai oval dengan latar belakang yang tenang.
2. **Rencana Cadangan Terukur Bila Kamera Ruangan Menyebabkan Skor Rendah**:
   - Jangan pernah menjanjikan klaim akurasi pada wajah nyata; paparkan secara ilmiah bahwa fenomena tersebut adalah bukti empiris risiko **`R-02` (selisih domain sintetis → nyata)** yang telah dianalisis di `ml/reports/analysis.md`.
   - Tunjukkan bukti matematis bahwa pipeline model & paritas lintas bahasa berjalan akurat pada distribusi uji melalui `pytest` (`ml/`) dan `flutter test` golden parity (`mobile/`).
   - Bila diperlukan khusus untuk memperagakan kelancaran transaksi Skenario 3 di ruangan redup, nilai `FACE_SIMILARITY_THRESHOLD` dapat disesuaikan sementara lewat `admin/.env` diikuti `php artisan config:clear` (tanpa mengubah kode), lalu dikembalikan ke nilai validasi resmi `0.2167`.
   - Siapkan pula rekaman layar cadangan (*screen recording*) dari sesi gladi bersih yang sukses di perangkat yang sama (`T-406`).
