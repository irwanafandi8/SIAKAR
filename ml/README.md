# Modul Machine Learning SIAKAR (`ml/`)

Pipeline model AI pengenalan wajah untuk SIAKAR dibangun dan dilatih **dari nol** tanpa bobot pretrained, tanpa Colab (menggunakan TensorFlow/Keras dan scikit-learn/scikit-image lokal di CPU).

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
│   ├── raw/digiface/           # subset DigiFace-1M (subj_id/0.png ... 71.png)
│   ├── splits/                 # split.json, pairs_val.json, pairs_test.json
│   └── negatives/              # gambar non-wajah
├── src/siakar_ml/
│   ├── data/
│   │   ├── prepare_digiface.py # penyiapan & validasi struktur subset DigiFace-1M (T-103)
│   │   └── split.py            # pembagian deterministik A/B/C & pasangan verifikasi (T-105)
│   ├── preprocess.py           # implementasi praproses tunggal (T-104)
│   ├── models/
│   │   ├── baseline_classic.py # baseline klasik HOG, LBP, dan HOG+LBP (T-106)
│   │   ├── embedding_cnn.py
│   │   └── detector_cnn.py
│   ├── train_embedding.py
│   ├── evaluate.py             # metrik klasifikasi & verifikasi (FAR, FRR, EER, ROC AUC, TAR@FAR)
│   └── export_tflite.py        # ekspor .tflite + uji paritas golden vectors
├── artifacts/                  # model .keras, model .tflite, threshold.json, preprocess.json
├── reports/                    # grafik evaluasi (png), tabel metrik (csv), analysis.md
└── tests/                      # unit test praproses, split, baseline & metrik
```

## Dataset & Lisensi (T-103)

- **DigiFace-1M** (Microsoft Research):
  - **Deskripsi**: Dataset wajah sintetis hasil render 3D (bagian 72 gambar/identitas: 10.000 identitas × 4 set aksesori × 18 pose/pencahayaan = 720.000 citra berukuran 112×112 RGB).
  - **Lokasi lokal**: `ml/data/raw/digiface/<id_identitas>/<indeks>.png` (dikecualikan oleh `.gitignore`, tidak di-commit ke repositori).
  - **Lisensi**: Microsoft DigiFace-1M License — khusus penggunaan **riset akademik / non-komersial** (tidak menggunakan foto wajah orang sungguhan; wajib menyertakan berkas `LICENSE` asli dari repositori resmi `microsoft/DigiFace1M`).
  - **Sitasi resmi**:
    > Gwangbin Bae, Martin de La Gorce, Tadas Baltrušaitis, Charlie Hewitt, Dong Chen, Julien Valentin, Roberto Cipolla, and Jingjing Shen. *"DigiFace-1M: 1 Million Synthetic Faces for Face Recognition"*, IEEE/CVF Winter Conference on Applications of Computer Vision (WACV), 2023.
- **Data negatif (non-wajah) & Liveness (`T-108` / `D-44` / `Q-2`)**:
  1. **Generator Non-Wajah Prosedural Sintetis (`siakar_ml.data.prepare_negatives`)**:
     - **Deskripsi**: Citra non-wajah 100% sintetis (gradien cahaya ruangan, kisi ubin, garis arsitektural/tirai, tekstur frekuensi multi-skala, blok objek latar, dan derau sensor) di `ml/data/negatives/synthetic/` ditambah potongan latar/sudut ekstrem di luar wajah.
     - **Lisensi**: Kode internal proyek SIAKAR (bebas masalah privasi & patuh penuh `D-40` tanpa foto manusia nyata).
  2. **Describable Textures Dataset — DTD (Opsional Eksternal untuk Memperkaya Latar)**:
     - **Deskripsi**: 5.640 citra tekstur material/permukaan benda murni (kayu, kain, dinding, kisi, batu) tanpa wajah manusia; dapat diekstrak ke `ml/data/negatives/dtd/`.
     - **Lisensi**: Lisensi riset akademik non-komersial Visual Geometry Group (University of Oxford).
     - **Sitasi**: M. Cimpoi, S. Maji, I. Kokkinos, S. Mohamed, and A. Vedaldi, *"Describing Textures in the Wild"*, IEEE CVPR, 2014.
  3. **FractalDB (Opsional Sintetis Matematis)**:
     - **Deskripsi**: Citra fraktal hasil rumus matematis tanpa foto dunia nyata.
     - **Lisensi**: CC BY 4.0 / penggunaan riset akademik (*Kataoka et al., ACCV 2020*).
  4. **Data Liveness**: Tidak membutuhkan dataset eksternal pada cakupan utama karena memakai **Level L1** (*challenge-response* berbasis perubahan skor & koordinat kotak `[cx, cy, w, h]` detektor antar-frame sesuai `ML_SPEC.md` §3.4 & `D-27`).

## Lingkungan & Kompatibilitas

- Python: 3.10.x (didukung penuh oleh TensorFlow 2.15 CPU Windows)
- Paket utama: `tensorflow==2.15.0`, `numpy<2.0`, `scikit-learn>=1.3`, `scikit-image>=0.21`, `opencv-python-headless>=4.8`, `matplotlib>=3.7`, `pytest>=7.4`.

## Perintah Menjalankan Pipeline (PowerShell)

```powershell
cd ml
.\.venv\Scripts\Activate.ps1
$env:PYTHONPATH = "src"

# 1. Validasi / ekstrak subset DigiFace-1M (T-103)
python -m siakar_ml.data.prepare_digiface --raw-dir data/raw/digiface --stats-out reports/dataset_stats.json

# 2. Buat split deterministik A/B/C + pairs_val.json & pairs_test.json (T-105)
python -m siakar_ml.data.split --config configs/embedding.yaml

# 3. Jalankan baseline klasik HOG & LBP beserta evaluasi metrik & grafik (T-106)
python -m siakar_ml.models.baseline_classic --config configs/embedding.yaml --methods hog lbp hog_lbp

# 4. Benchmark 1 epoch CNN embedding dari nol untuk mengukur waktu/RAM & usulan D-46 (T-107)
python -m siakar_ml.benchmark_epoch --config configs/embedding.yaml

# 5. Latih model CNN penuh + checkpointing & early stopping (T-201, T-202)
python -m siakar_ml.train_embedding --config configs/embedding.yaml

# 6. Evaluasi klasifikasi & verifikasi -> threshold.json & reports/analysis.md (T-202, T-203)
python -m siakar_ml.evaluate --config configs/embedding.yaml --model artifacts/embedding_training.keras --run-name main_cnn

# 7. Ekspor siakar_embedding.tflite + uji paritas + golden vectors + salin ke mobile/ (T-204)
python -m siakar_ml.export_tflite --config configs/embedding.yaml --copy-to-mobile

# 8. Siapkan data negatif non-wajah sintetis & latih + ekspor detektor wajah detector.tflite (T-108, T-205)
python -m siakar_ml.data.prepare_negatives --negative-dir data/negatives --n-synthetic 4000
python -m siakar_ml.train_detector --config configs/detector.yaml --copy-to-mobile

# 9. Jalankan seluruh unit test
python -m pytest -v
```
