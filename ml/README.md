# Modul Machine Learning SIAKAR (`ml/`)

Pipeline model AI pengenalan wajah untuk SIAKAR dibangun dan dilatih **dari nol** tanpa bobot pretrained, tanpa Colab (menggunakan TensorFlow/Keras lokal di CPU).

## Struktur Folder

```
ml/
├── README.md
├── requirements.txt
├── configs/
│   ├── embedding.yaml
│   ├── detector.yaml
│   └── liveness.yaml
├── data/                       # TIDAK di-commit (.gitignore)
│   ├── raw/digiface/           # subset DigiFace-1M
│   ├── splits/                 # split.json, pairs_val.json, pairs_test.json
│   └── negatives/              # gambar non-wajah
├── src/siakar_ml/
│   ├── data/                   # data loader, tf.data pipeline
│   ├── preprocess.py           # implementasi praproses tunggal
│   ├── models/                 # embedding_cnn.py, detector_cnn.py, liveness_cnn.py, baseline_classic.py
│   ├── train_embedding.py
│   ├── train_detector.py
│   ├── train_liveness.py
│   ├── evaluate.py             # evaluasi FAR, FRR, EER, ROC AUC
│   └── export_tflite.py        # ekspor .tflite + uji paritas golden vectors
├── artifacts/                  # model .keras, model .tflite, threshold.json, preprocess.json
├── reports/                    # grafik evaluasi (png), tabel metrik (csv), analysis.md
└── tests/                      # unit test praproses, split, ekspor
```

## Dataset & Lisensi

- **DigiFace-1M**: Dataset wajah sintetis yang dibuat oleh Microsoft Research (10k identitas × 72 gambar, potongan 112×112).
  - Lisensi: CC BY-NC 4.0 / Riset Non-komersial.
  - Sitasi: Bae et al., "DigiFace-1M: 1 Million Synthetic Faces for Face Recognition", WACV 2023.
- Data negatif (non-wajah): (diisi pada T-108).

## Lingkungan & Kompatibilitas

- Python: 3.10.x
- TensorFlow: Dipilih versi yang kompatibel (mis. TensorFlow 2.10–2.15 untuk CPU Windows).
