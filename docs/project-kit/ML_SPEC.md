# ML_SPEC.md — Spesifikasi Model AI SIAKAR

Mengikuti `DECISIONS.md` (D-20 s.d. D-31, D-40 s.d. D-46). Jika konflik, DECISIONS.md menang.

## 0. Prinsip

1. **Dari nol.** Tidak ada bobot pretrained, tidak ada model pihak ketiga untuk deteksi, embedding, atau liveness. Library umum (TensorFlow/Keras, NumPy, scikit-learn, scikit-image, OpenCV untuk operasi gambar biasa) boleh. Fungsi deteksi wajah bawaan OpenCV (Haar/DNN) dan ML Kit **tidak boleh**.
2. **Tanpa Colab.** Semua jalan di Python lokal (virtualenv) di dalam folder `ml/`, CPU saja (laptop RAM 8 GB, tanpa GPU).
3. **Setiap tahap punya empat hal** (syarat dosen AI): konsep, kode, hasil, analisis. Hasil dan analisis disimpan di `ml/reports/`.
4. **Hasil jujur.** Dosen AI menerima akurasi berapa pun, asal ada hasil dan analisis. Jangan menyetel ulang pada data uji.
5. **Prioritas:** (1) model embedding → (2) detektor wajah → (3) liveness. Jangan mengerjakan (3) sebelum (1) dan (2) berjalan end-to-end.

## 1. Struktur `ml/`

```
ml/
├── README.md
├── requirements.txt            # pin versi; cek kompatibilitas versi Python dengan TensorFlow
├── configs/
│   ├── embedding.yaml          # hyperparameter, ukuran input, jumlah identitas subset, seed
│   ├── detector.yaml
│   └── liveness.yaml
├── data/                       # TIDAK di-commit (.gitignore)
│   ├── raw/digiface/           # subj_id_n/k.png
│   ├── splits/                 # embedding_split.json (daftar identitas & gambar per split)
│   └── negatives/              # gambar non-wajah (sumber: OPEN)
├── src/siakar_ml/
│   ├── data/                   # loader tf.data, split, pasangan verifikasi, augmentasi
│   ├── preprocess.py           # SATU-SATUNYA implementasi praproses (lihat §4)
│   ├── models/                 # embedding_cnn.py, detector_cnn.py, liveness_cnn.py, baseline_classic.py
│   ├── train_embedding.py
│   ├── train_detector.py
│   ├── train_liveness.py
│   ├── evaluate.py             # klasifikasi + verifikasi + kurva + laporan
│   └── export_tflite.py        # ekspor + uji paritas + golden vectors
├── artifacts/                  # checkpoint, model .keras, model .tflite, threshold.json
├── reports/                    # tabel hasil (csv), grafik (png), analisis (md)
└── tests/                      # unit test praproses, split, metrik, ekspor
```

## 2. Data

### 2.1 Sumber (lihat D-40 s.d. D-46)

- **DigiFace-1M** (usulan). Struktur: `subj_id_n/0.png … k.png`. Bagian 72-gambar-per-identitas: 10 ribu identitas × 72 gambar (4 set aksesori × 18 gambar). Potongan wajah 112×112 yang sudah diselaraskan. Lisensi non-komersial riset; baca `LICENSE`.
- Jangan memuat seluruh dataset ke RAM. Pakai `tf.data` dengan pembacaan dari disk, `prefetch`, dan batch kecil.
- Jumlah identitas subset (`n_identities`) di `configs/embedding.yaml`. Mulai kecil (mis. 500), ukur waktu per epoch, naikkan bertahap.

### 2.2 Pembagian data (wajib per identitas, seed dikunci)

Identitas dibagi **tiga kelompok yang tidak beririsan**:

| Kelompok | Fungsi |
|---|---|
| **A: identitas latih** | Melatih classifier + embedding. Gambar di A dibagi lagi untuk uji klasifikasi (di bawah) |
| **B: identitas validasi** | Memilih ambang verifikasi dan menyetel hyperparameter (identitas tidak pernah dilatih) |
| **C: identitas uji** | Uji verifikasi akhir (identitas tidak pernah dilatih dan tidak dipakai menyetel) |

Di dalam kelompok A, untuk **uji klasifikasi**: pisahkan **set aksesori** (mis. 3 set untuk latih, 1 set untuk uji) sehingga gambar uji berasal dari kondisi yang tidak terlihat saat pelatihan. Jangan acak per gambar.

`split.json` menyimpan daftar path dan dibuat sekali. Semua skrip membaca file yang sama.

### 2.3 Augmentasi (hanya data latih)

Tujuan: mengecilkan selisih domain ke foto kamera ponsel (R-02, R-03). Parameter di config, nilai awal sebagai usulan:

| Augmentasi | Rentang awal |
|---|---|
| Kecerahan / kontras / gamma | ±30% |
| Gaussian blur ringan, derau | σ 0–1.5 / kecil |
| Kompresi JPEG | kualitas 50–95 |
| Rotasi kecil | ±10° (alignment-free) |
| Skala dan geser | ±10% (alignment-free) |
| Flip horizontal | 50% |
| Pergeseran warna/saturasi ringan | kecil |

Augmentasi **tidak** dipakai pada data validasi/uji.

## 3. Model

### 3.1 Embedding CNN (inti)

- **Input:** `[112, 112, 3]` RGB float32 (boleh diturunkan ke 96 atau 64 bila CPU terlalu lambat; ubah di config dan **ekspor ulang**; ukuran input menjadi bagian kontrak §5).
- **Backbone (usulan, boleh disesuaikan):** blok Conv2D 3×3 + BatchNorm + ReLU, downsampling bertahap.

| Tahap | Keluaran kasar | Catatan |
|---|---|---|
| Stem: Conv 3×3 stride 2, 32 filter | 56×56×32 | |
| Blok 1: 2× Conv 3×3, 64 filter, stride 2 di awal | 28×28×64 | |
| Blok 2: 2× Conv 3×3, 128 filter, stride 2 | 14×14×128 | |
| Blok 3: 2× Conv 3×3, 256 filter, stride 2 | 7×7×256 | |
| GlobalAveragePooling | 256 | |
| Dense 128 (linear) → **L2 normalize** | **128** | **Embedding** |
| Kepala latih: Dense `n_identities` + softmax | — | Dibuang saat ekspor |

- Hanya lapisan standar yang aman dikonversi TFLite: `Conv2D`, `DepthwiseConv2D`, `BatchNormalization`, `ReLU`, `MaxPool/AvgPool`, `GlobalAveragePooling2D`, `Dense`, `tf.math.l2_normalize`. Hindari `Lambda` custom dan operasi yang jarang didukung (R-06). Target ukuran parameter di bawah beberapa juta.
- **Loss:** mulai dari softmax cross-entropy. Opsional (bila waktu ada): margin berbasis kosinus yang **diimplementasikan sendiri** (mis. CosFace/ArcFace head) sebagai ablasi. Itu hanya fungsi loss, bukan bobot pretrained.
- **Optimizer:** Adam, learning rate awal 1e-3, `ReduceLROnPlateau` atau cosine decay; batch 32–64; early stopping pada validasi; **simpan checkpoint tiap epoch** (resume).
- Ukur waktu 1 epoch pada subset kecil **sebelum** menjadwalkan percobaan penuh.

### 3.2 Baseline klasik (pembanding)

HOG atau LBP-histogram dari gambar yang sama (grayscale, ukuran sama) → vektor fitur → (a) cosine similarity untuk verifikasi, (b) SVM linear untuk klasifikasi. Implementasi dengan scikit-image/scikit-learn. Tujuan: menunjukkan seberapa jauh CNN melampaui metode klasik, dan memberi angka acuan sejak awal.

### 3.3 Detektor wajah (prioritas 2)

- Tujuan di aplikasi: memastikan **ada wajah di dalam oval panduan** sebelum mengambil gambar (bukan mencari wajah di seluruh frame).
- Rancangan awal: CNN kecil klasifikasi **wajah / bukan wajah** pada potongan di area oval (ukuran mis. 64×64). Positif: potongan wajah (mis. DigiFace, digeser/diskalakan acak untuk meniru posisi tidak sempurna). Negatif: gambar non-wajah dan potongan acak latar (sumber **OPEN**, D-44).
- Keluaran: skor wajah ∈ [0,1] + ambang. Tambahan opsional: regresi kotak sederhana bila waktu ada.
- Dievaluasi: akurasi, presisi/recall, dan uji sederhana pada tangkapan kamera sintetis.

### 3.4 Liveness (prioritas 3)

- **Level L1 (fallback, D-27):** challenge-response acak tanpa model (mis. "geser wajah ke kiri lalu ke kanan") yang diukur dari perubahan posisi/skala skor/kotak detektor antar-frame.
- **Level L2 (bila waktu ada):** classifier kecil keadaan mata (terbuka/tertutup) untuk deteksi kedip. Bergantung pada ketersediaan data (D-44).
- **Batasan yang harus ditulis di laporan:** challenge-response **tidak** menahan serangan video atau topeng.

## 4. Kontrak Praproses (satu spesifikasi, dua implementasi)

Praproses **harus identik** di Python (pelatihan/evaluasi/ekspor) dan Dart (aplikasi). Implementasi referensi: `ml/src/siakar_ml/preprocess.py`. Bila ada perbedaan, Python menang.

| Langkah | Spesifikasi |
|---|---|
| 1. Crop | Area dalam oval panduan (rasio dan posisi didefinisikan di `preprocess.json`, satu sumber untuk Python dan Dart) |
| 2. Resize | Ke `input_size × input_size` (default 112), interpolasi **bilinear**, tanpa mempertahankan rasio (crop sudah persegi) |
| 3. Urutan kanal | **RGB** |
| 4. Tipe/rentang | Piksel uint8 → float32 → `(x − 127.5) / 127.5` → rentang [−1, 1] |
| 5. Bentuk | `[1, H, W, 3]` (NHWC) |

Catatan: nilai persis crop, resize, dan normalisasi harus **ditulis ke `ml/artifacts/preprocess.json`** dan dibaca oleh kedua sisi sebagai satu-satunya sumber nilai.

## 5. Kontrak Ekspor TFLite

| Item | Nilai |
|---|---|
| File | `ml/artifacts/siakar_embedding.tflite` → disalin ke `mobile/assets/models/` |
| Input | `float32 [1, H, W, 3]`, H = W = `input_size` (default 112), RGB, [−1, 1] |
| Output | `float32 [1, 128]`, **sudah L2-normalized** |
| Presisi | float32 dulu. Kuantisasi float16/int8 hanya sebagai optimisasi setelah akurasi tervalidasi, dan wajib diuji ulang |
| Ekspor | `tf.lite.TFLiteConverter.from_keras_model(...)`, model **tanpa** kepala softmax |
| Golden vectors | `ml/artifacts/golden/`: beberapa gambar contoh + embedding Keras + embedding TFLite (JSON) |

**Uji paritas (wajib, otomatis):**
1. Keras vs TFLite (Python): cosine similarity embedding ≥ 0.999 pada golden images.
2. Dart vs Python: praproses di Dart pada golden images menghasilkan embedding dengan cosine ≥ 0.99 terhadap embedding referensi. Tes ini ada di `mobile/test/`.

## 6. Protokol Evaluasi

Semua angka dihitung oleh `evaluate.py` dan ditulis ke `ml/reports/*.csv` + `*.png` + `analysis.md`. Seed dikunci.

### 6.1 Klasifikasi (set tertutup)

- Data uji: set aksesori yang ditahan dari identitas kelompok A (§2.2).
- Metrik: akurasi top-1, (opsional) top-5, akurasi per identitas dan identitas yang paling sering salah.
- Pembanding: SVM pada fitur HOG/LBP.

### 6.2 Verifikasi (set terbuka, identitas baru)

- Pasangan dibuat **tetap** (seed) dan disimpan: `pairs_val.json`, `pairs_test.json`.
  - Genuine: dua gambar identitas sama, **diutamakan dari set aksesori berbeda**.
  - Impostor: dua gambar dari identitas berbeda.
  - Jumlah pasangan seimbang (mis. beberapa ribu per kelas; ditentukan di config).
- Skor: cosine similarity embedding.
- **Ambang dipilih di pasangan validasi (kelompok B), lalu dipakai apa adanya di pasangan uji (kelompok C).** Jangan memilih ambang pada data uji.
- Metrik: FAR, FRR, **EER**, ROC AUC, TAR@FAR (1% dan 0,1%), dan akurasi verifikasi pada ambang terpilih.
- Pembanding: baseline HOG/LBP dengan protokol identik.

### 6.3 Ablasi minimal (bahan analisis)

Pilih 2–3 yang realistis: dengan/tanpa augmentasi; dimensi embedding (mis. 64 vs 128); loss softmax vs margin; ukuran input (96 vs 112). Tiap ablasi: satu tabel, satu paragraf analisis.

### 6.4 Pengukuran perangkat

Di ponsel Android sungguhan: waktu praproses + inferensi embedding (ms, rata-rata beberapa kali jalan) dan waktu absen ujung ke ujung (target < 5 detik; **ukur, jangan diasumsikan**).

### 6.5 Selisih domain (wajib dibahas)

Semua data latih dan uji bersifat sintetis. Tuliskan eksplisit di laporan bahwa angka evaluasi belum tentu berlaku pada wajah nyata. Uji coba aplikasi dengan wajah anggota kelompok hanya sebagai **uji asap (smoke test)**: tidak dilaporkan sebagai akurasi, foto tidak masuk repositori, dan dilakukan dengan persetujuan yang bersangkutan.

## 7. Penentuan Ambang untuk Aplikasi

1. `evaluate.py` menghitung ambang pada validasi (mis. titik EER atau FAR target) dan menulis `ml/artifacts/threshold.json` dengan field `threshold`, `metric_basis`, `far`, `frr`, `val_pairs`, `date`.
2. Nilai disalin ke `admin/config/face.php` (dapat di-override lewat `.env`).
3. Laporan menyebut dasar pemilihan ambang, bukan hanya angkanya.

## 8. Keluaran yang Diminta Dosen AI (per tahap)

| Tahap | Konsep | Kode | Hasil | Analisis |
|---|---|---|---|---|
| Data dan praproses | mengapa split per identitas, augmentasi | `data/`, `preprocess.py` | statistik dataset, contoh gambar | dampak augmentasi |
| Baseline klasik | HOG/LBP | `baseline_classic.py` | metrik §6 | kekuatan/kelemahan |
| CNN embedding | konvolusi, embedding, loss | `models/`, `train_embedding.py` | kurva latih/valid, metrik §6 | perbandingan vs baseline, ablasi |
| Detektor | klasifikasi biner | `train_detector.py` | metrik detektor | kesalahan umum |
| Liveness | challenge-response / klasifikasi | sesuai level | hasil uji | batasan keamanan |
| Integrasi | ekspor TFLite, paritas | `export_tflite.py` | hasil uji paritas, latensi | selisih domain, keterbatasan |

## 9. Kriteria Selesai (ML)

- [ ] Split dan pasangan verifikasi tersimpan dan dapat direproduksi (seed).
- [ ] Baseline klasik dievaluasi dengan protokol §6.
- [ ] CNN embedding dilatih, dievaluasi (klasifikasi dan verifikasi), dan dibandingkan dengan baseline.
- [ ] `siakar_embedding.tflite` + `preprocess.json` + `threshold.json` + golden vectors tersedia.
- [ ] Uji paritas §5 lulus.
- [ ] Detektor wajah berjalan di aplikasi (minimal tervalidasi pada data sintetis).
- [ ] Laporan hasil dan analisis (`ml/reports/analysis.md`) menyebut keterbatasan selisih domain.
- [ ] Liveness: minimal L1 berjalan, batasannya tertulis.
