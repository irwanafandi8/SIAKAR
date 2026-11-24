# TASKS.md — Backlog 4 Minggu SIAKAR

Isi kolom tanggal dan PIC (penanggung jawab) sendiri. Empat jalur kerja (disarankan satu orang per jalur, saling membantu):

| Jalur       | Cakupan                                                                  |
| ----------- | ------------------------------------------------------------------------ |
| **ML**      | Dataset, model embedding, baseline, detektor, liveness, evaluasi, ekspor |
| **MOB**     | Aplikasi Flutter                                                         |
| **BE**      | Laravel API, basis data                                                  |
| **ADM+DOC** | Admin Blade, pengujian, dokumen dan laporan (PM2, AI, progres mingguan)  |

Aturan: jalur kritis adalah **ML**. Jika jalur ML terlambat, prioritaskan memperkecil lingkup (D-26, D-27), bukan menambah fitur. Tiap minggu kirim **laporan progres + tautan Google Drive** ke dosen AI (kolom komentar tugas).

Format tugas: `ID` · jalur · deskripsi · **Selesai bila** (kriteria yang dapat diperiksa).

---

## Minggu 1: Fondasi dan data (jalur kritis: ML)

| ID    | Jalur | Tugas                                                                                                  | Selesai bila                                                                       |
| ----- | ----- | ------------------------------------------------------------------------------------------------------ | ---------------------------------------------------------------------------------- |
| T-101 | ALL   | Buat monorepo (`mobile/ admin/ ml/ docs/`), `.gitignore` (data, `.env`, venv), salin AGENTS.md ke root | Repo bisa di-clone; struktur sesuai DESIGN §4                                      |
| T-102 | ML    | Siapkan venv Python + `requirements.txt` (TensorFlow versi yang cocok dengan Python), uji instalasi    | `python -c "import tensorflow"` jalan; versi tercatat                              |
| T-103 | ML    | ✅ Unduh/siapkan subset DigiFace-1M, baca `LICENSE`, catat sitasi                                      | Skrip penyiapan siap; lisensi & sitasi dicatat di `ml/README.md` (Selesai kode)    |
| T-104 | ML    | Tulis `preprocess.py` + `preprocess.json` + tes unit                                                   | Tes lulus; satu fungsi praproses                                                   |
| T-105 | ML    | ✅ Skrip split per identitas (A/B/C) + pasangan verifikasi, seed dikunci                               | `split.json`, `pairs_val.json`, `pairs_test.json` stabil lintas run (Pytest lulus) |
| T-106 | ML    | ✅ Baseline klasik HOG/LBP + evaluasi §6                                                               | Pipeline HOG/LBP + CSV/PNG metrik siap & unit test lulus (Siap run manual)         |
| T-107 | ML    | ✅ **Uji 1 epoch** CNN pada subset kecil; ukur waktu; putuskan `n_identities` dan ukuran input         | CNN, `tf.data`, & benchmark siap (Pytest 1-batch lulus; jalankan manual untuk D-46) |
| T-108 | ML    | ✅ Cari sumber data non-wajah (detektor) dan data liveness + lisensi                                   | Daftar sumber & lisensi tercatat di `ml/README.md` & `DECISIONS.md` (`Q-2` terjawab) |
| T-111 | BE    | Proyek Laravel, koneksi MySQL, timezone Asia/Jakarta, Sanctum                                          | `php artisan migrate` jalan                                                        |
| T-112 | BE    | Migrasi semua tabel (DESIGN §5), model, seeder demo                                                    | `migrate --seed` menghasilkan data demo                                            |
| T-113 | BE    | `ApiResponse`, `/auth/login` (+device binding), `/auth/logout`, `/me`                                  | Feature test auth lulus                                                            |
| T-121 | MOB   | Proyek Flutter, struktur Clean Architecture, DI, router, tema dari token                               | `flutter run` menampilkan layar login bertema                                      |
| T-122 | MOB   | Dio client + interceptor + pemetaan error; layar Login terhubung API                                   | Login berhasil ke API lokal                                                        |
| T-131 | DOC   | Sinkronkan laporan analisis sesuai DECISIONS §5; ajukan Q-1, Q-5, Q-7 ke dosen                         | Laporan/PPT sinkron; jawaban dosen dicatat                                         |
| T-132 | DOC   | Laporan progres minggu 1 + tautan Drive                                                                | Terkirim                                                                           |

## Minggu 2: Model dan fitur inti

| ID    | Jalur | Tugas                                                                                      | Selesai bila                                                                |
| ----- | ----- | ------------------------------------------------------------------------------------------ | --------------------------------------------------------------------------- |
| T-201 | ML    | ✅ Arsitektur CNN embedding + pipeline `tf.data` + augmentasi                              | Pipeline siap & dry-run pytest lulus (siap latihan subset penuh manual)     |
| T-202 | ML    | ✅ Latih model penuh dengan checkpoint tiap epoch; evaluasi klasifikasi + verifikasi       | Checkpoint, resume, evaluasi §6, & kurva siap (siap eksekusi penuh manual)  |
| T-203 | ML    | ✅ Ablasi minimal (2–3 percobaan) + analisis                                               | Dukungan ablasi (`no-aug`, `dim64`, `cosface`) & generator `analysis.md` siap |
| T-204 | ML    | ✅ **Ekspor TFLite + uji paritas Keras↔TFLite + golden vectors** (jangan tunda)            | Skrip ekspor `.tflite`, `threshold.json`, golden & paritas ≥0,999 lulus pytest |
| T-205 | ML    | ✅ Detektor wajah (data negatif dari T-108) + evaluasi                                     | Skrip latih, evaluasi, ekspor `detector.tflite`, & golden lulus pytest (siap run manual) |
| T-211 | BE    | `FaceMatchService` (cosine), `GeofenceService` (Haversine) + tes unit                      | Tes unit lulus                                                              |
| T-212 | BE    | `/face/enroll`, `/face/status` (enkripsi, rata-rata, foto privat)                          | Feature test lulus                                                          |
| T-213 | BE    | ✅ `/attendance/today`, `check-in`, `check-out`, `history` sesuai urutan API §3.3          | Feature test mencakup semua kode error §1 (Selesai)                         |
| T-221 | MOB   | Port praproses Dart + `embedding_service` (TFLite) + **tes paritas dengan golden vectors** | Cosine ≥ 0,99 terhadap referensi                                            |
| T-222 | MOB   | Kamera + oval panduan + GPS + izin (kontekstual)                                           | Berjalan di ponsel asli                                                     |
| T-223 | MOB   | Registrasi wajah end-to-end                                                                | Wajah terdaftar di DB lewat aplikasi                                        |
| T-231 | ADM   | ✅ Layout Blade + komponen (token desain) + login admin                                    | Halaman login/dasbor kosong bertema (Selesai)                               |
| T-232 | ADM   | ✅ CRUD karyawan, departemen, jabatan                                                      | Dapat tambah/ubah/nonaktifkan; reset wajah/perangkat (Selesai)              |
| T-233 | DOC   | Laporan progres minggu 2; mulai bab AI di laporan dari ML_SPEC                             | Terkirim                                                                    |

## Minggu 3: Integrasi dan fitur Should

| ID    | Jalur  | Tugas                                                                                             | Selesai bila                                         |
| ----- | ------ | ------------------------------------------------------------------------------------------------- | ---------------------------------------------------- |
| T-301 | MOB    | Absen masuk/pulang end-to-end (detektor → embedding → API → hasil)                                | Skenario demo 3, 4, 5 dapat dijalankan               |
| T-302 | MOB    | Beranda, Riwayat, Profil                                                                          | FR-05 memenuhi kriteria penerimaan                   |
| T-303 | ML+MOB | Integrasi detektor ke kamera; liveness L1 (challenge-response)                                    | Absen menolak bila detektor/liveness gagal           |
| T-304 | ML     | Ukur latensi di ponsel; uji asap singkat di ponsel (bukan akurasi) untuk memeriksa selisih domain | Angka latensi tercatat; catatan keterbatasan ditulis |
| T-311 | BE     | ✅ `/leaves`, `/approvals`, `/team/recap` + transaksi persetujuan                                 | Feature test lulus (Selesai)                         |
| T-321 | MOB    | Fitur izin (karyawan) + persetujuan + rekap (atasan)                                              | FR-06/07/08 berjalan                                 |
| T-331 | ADM    | ✅ CRUD shift, jadwal, lokasi, hari libur                                                         | FR-10/11 berjalan (Selesai)                          |
| T-332 | ADM    | ✅ Koreksi absensi + rekap laporan + CSV                                                          | FR-12/13/14 berjalan (Selesai)                       |
| T-333 | DOC    | Proposal PM2 (3–5 hal, PDF) dari PRD/DESIGN; laporan progres minggu 3                             | Terkirim                                             |
| T-334 | ML     | (Bila waktu ada) Liveness L2 atau loss margin                                                     | Hasil tercatat, atau dicoret dan dicatat alasannya   |

## Minggu 4: Stabilisasi, evaluasi, dokumen, demo

| ID    | Jalur | Tugas                                                                              | Selesai bila                                           |
| ----- | ----- | ---------------------------------------------------------------------------------- | ------------------------------------------------------ |
| T-401 | ALL   | **Bekukan fitur** (tidak ada fitur baru). Perbaiki bug                             | Daftar bug kritis kosong                               |
| T-402 | ALL   | Gladi demo penuh sesuai PRD §8 di perangkat dan jaringan yang akan dipakai         | Skenario 1–8 lolos, atau kegagalan sudah punya rencana |
| T-403 | ML    | Finalisasi `analysis.md`: hasil, perbandingan, ablasi, keterbatasan selisih domain | Dokumen final ditinjau                                 |
| T-404 | DOC   | Laporan AI (konsep, kode, hasil, analisis per tahap §8 ML_SPEC)                    | Final                                                  |
| T-405 | DOC   | Laporan akhir PM2 / MPPL, sinkron dengan DECISIONS                                 | Final                                                  |
| T-406 | ALL   | Siapkan demo: server berjalan, data seed, cadangan rekaman layar, skrip presentasi | Siap                                                   |
| T-407 | DOC   | Laporan progres minggu 4 + pengumpulan                                             | Terkirim                                               |
| T-408 | ALL   | Cadangan: 3 hari terakhir hanya untuk perbaikan dan latihan presentasi             | Tidak ada pekerjaan fitur                              |

## Jalur pengaman jika terlambat

1. Minggu 2 akhir: model belum layak → pakai hasil terbaik yang ada, **jujur** di analisis; jangan melatih tanpa batas.
2. Detektor/liveness bermasalah → liveness turun ke L1 (D-27), detektor disederhanakan ke validasi di area oval.
3. Waktu admin habis → tinggalkan Could (grafik, PDF/Excel, peta); pertahankan FR-10/13.
4. Izin (FR-06..08) belum selesai di minggu 3 → kerjakan hanya alur dasar (ajukan + setujui), tanpa lampiran.
