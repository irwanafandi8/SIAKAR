---
name: ml-train-evaluate-export
description: Melatih, mengevaluasi, dan mengekspor model SIAKAR (CNN embedding dari nol) di Python lokal sesuai ML_SPEC.md, termasuk pembagian data per identitas, metrik FAR/FRR/EER, ekspor TFLite, dan uji paritas. Gunakan untuk semua pekerjaan di folder ml/.
---

# Skill: ml-train-evaluate-export

Baca dulu: `ML_SPEC.md` (seluruhnya), `DECISIONS.md` D-20..D-31, D-40..D-46.

## Aturan keras

- **Tanpa bobot pretrained dan tanpa model pihak ketiga.** Tanpa Colab. CPU, RAM 8 GB: jangan memuat seluruh dataset ke memori.
- Seed dikunci; tidak mengatur ulang hyperparameter berdasarkan data uji; ambang dipilih di validasi.

## Urutan kerja

1. **Praproses dulu** (`preprocess.py` + `preprocess.json` + tes unit). Semua skrip lain memakainya.
2. **Split** per identitas (A/B/C) + pasangan verifikasi tetap, simpan ke JSON. Tes: tidak ada identitas yang sama di dua kelompok.
3. **Baseline klasik** (HOG/LBP) dan evaluasinya, sebagai acuan sejak awal.
4. **Uji 1 epoch** pada subset kecil, ukur waktu, tentukan `n_identities` dan ukuran input. Baru lakukan latihan penuh.
5. **Latih CNN** dengan `tf.data` (baca dari disk, `prefetch`), augmentasi hanya pada data latih, checkpoint tiap epoch, early stopping.
6. **Evaluasi** (`evaluate.py`): klasifikasi (set aksesori yang ditahan) dan verifikasi (identitas baru): FAR, FRR, EER, ROC AUC, TAR@FAR. Tulis CSV, PNG, dan paragraf analisis ke `ml/reports/`.
7. **Ambang:** hitung di pasangan validasi → `ml/artifacts/threshold.json` → salin ke `admin/config/face.php`.
8. **Ekspor TFLite** tanpa kepala softmax; keluaran `[1,128]` L2-normalized. Segera lakukan **uji paritas** Keras↔TFLite dan simpan **golden vectors**. Lakukan ekspor percobaan sejak minggu awal, bukan di akhir.
9. **Salin artefak** ke `mobile/assets/models/` dan pastikan tes paritas Dart lulus.

## Keluaran per tahap (syarat dosen AI)

Untuk setiap tahap: konsep (apa/mengapa), kode, hasil (tabel/grafik), analisis (mengapa hasilnya begitu, kesalahan umum, keterbatasan). Tulis keterbatasan selisih domain sintetis→nyata dengan jelas.

## Larangan

- Jangan mengklaim akurasi pada wajah nyata. Jangan menyimpan atau meng-commit foto nyata.
- Jangan mengubah kontrak input/output model tanpa memperbarui `ML_SPEC.md` §5 dan `preprocess.json`.
