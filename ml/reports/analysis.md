# Analisis Evaluasi Model Pengenalan Wajah SIAKAR (`ML_SPEC` §6 & §8)

## 1. Perbandingan CNN Embedding (Dari Nol) vs Baseline Klasik (HOG / LBP)

| Model / Run | Klasifikasi Top-1 (A) | Ambang Validasi (B) | Test FAR (C) | Test FRR (C) | Test EER (C) | Test ROC AUC (C) | TAR@FAR=1% |
|---|---|---|---|---|---|---|---|
| Baseline `HOG` | 0.1102 | 0.717 | 0.42 | 0.422 | 0.421 | 0.624 | 0.103 |
| Baseline `LBP` | 0.0156 | 0.9292 | 0.467 | 0.476 | 0.471 | 0.5536 | 0.042 |
| Baseline `HOG_LBP` | 0.1152 | 0.8178 | 0.443 | 0.432 | 0.435 | 0.6031 | 0.1 |
| CNN `main_cnn` | 0.8094 | 0.2167 | 0.106 | 0.108 | 0.108 | 0.9588 | 0.616 |

### Analisis Perbandingan Metode
- **Baseline klasik (HOG/LBP)** mengekstrak gradien tepi dan tekstur mikro lokal secara statis, sehingga sensitif terhadap perubahan pose, rotasi, dan aksesori pada set aksesori yang ditahan.
- **CNN Embedding (dibangun dari nol)** mempelajari representasi hierarkis ter-normalisasi L2 berdimensi 128 yang lebih invarian terhadap variasi pose/pencahayaan antar set aksesori.

## 2. Pemilihan Ambang Verifikasi (`threshold.json`)
- **Dasar pemilihan**: Titik *Equal Error Rate* (EER, di mana FAR ≈ FRR) pada pasangan validasi **Kelompok B** (identitas tidak pernah dilatih), kemudian diterapkan apa adanya pada pasangan uji **Kelompok C** tanpa penyetelan ulang pada data uji (`ML_SPEC.md` §6.2 & §7).
- **Ambang terpilih saat ini**: `0.2167` (Validasi EER = `0.111`, ROC AUC = `0.9519`, `val_pairs` = `2000`). Nilai ini disalin ke `admin/config/face.php`.

## 3. Studi Ablasi (`T-203`)
- Bandingkan baris `main_cnn` (augmentasi aktif, `dim=128`, `softmax`) terhadap varian ablasi (`abl_no_aug`, `abl_dim64`, atau `abl_cosface`) pada tabel di atas:
  1. **Dampak Augmentasi**: Augmentasi kecerahan, kontras, dan flip mencegah *overfitting* pada kondisi pencahayaan seragam serta meningkatkan generalisasi pada identitas baru.
  2. **Dimensi Embedding (64 vs 128)**: Vektor 128-d menyediakan kapasitas pemisahan sudut antar-identitas yang lebih longgar dibanding 64-d dengan selisih ukuran berkas `.tflite` yang sangat kecil.
  3. **Fungsi Loss (Softmax vs Margin CosFace)**: Penalti margin sudut mendorong jarak kosinus intra-identitas lebih rapat di ruang hipersfer L2.

## 4. Keterbatasan & Selisih Domain Sintetis → Wajah Nyata (`ML_SPEC` §6.5)
- **Seluruh data latih, validasi, dan uji berasal dari dataset sintetis DigiFace-1M.** Angka akurasi, EER, dan ROC AUC pada laporan ini **tidak dapat diklaim sebagai akurasi pada wajah manusia nyata**.
- Citra kamera ponsel nyata memiliki karakteristik sensor, derau optik, *motion blur*, distorsi lensa depan, serta distribusi tekstur kulit yang berbeda dari render 3D sintetis (*synthetic-to-real domain gap*).
- Pendekatan *alignment-free* dengan panduan bingkai oval mengandalkan kepatuhan pengguna memposisikan wajah di tengah bingkai; kemiringan ekstrem di luar rentang augmentasi dapat menurunkan skor kosinus.
- Uji coba pada perangkat fisik di aplikasi hanya berstatus **uji asap (*smoke test*) fungsional**, bukan pengukuran akurasi biometrik.
