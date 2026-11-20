# SIAKAR — Sistem Absensi Karyawan Berbasis Mobile dengan Face Recognition

Proyek akhir lintas mata kuliah: MPPL, Pemrograman Mobile 2, Kecerdasan Buatan.  
Kelompok 9, D4RPL.2C.

## Struktur Repositori

```
SIAKAR/
├── mobile/   # Aplikasi Flutter (Android) — Clean Architecture + Cubit
├── admin/    # Backend Laravel (REST API /api/v1 + web admin Blade) + MySQL
├── ml/       # Pipeline ML Python: data, latih, evaluasi, ekspor TFLite
└── docs/     # Laporan dan project-kit (DECISIONS, PRD, DESIGN, API, ML_SPEC, dsb.)
```

## Cara Menjalankan

### Flutter (mobile/)
```bash
cd mobile
flutter pub get
flutter analyze
flutter test
flutter run          # sambungkan perangkat Android
```

### Laravel (admin/)
```bash
cd admin
cp .env.example .env
composer install
php artisan key:generate
# Edit .env: DB_DATABASE, DB_USERNAME, DB_PASSWORD
php artisan migrate --seed
php artisan serve    # API lokal di http://127.0.0.1:8000
# Asset admin:
npm install && npm run dev
```

### ML (ml/)
```bash
cd ml
python -m venv .venv
# Windows:
.venv\Scripts\activate
# Linux/Mac:
source .venv/bin/activate

pip install -r requirements.txt
# Latih embedding:
python -m siakar_ml.train_embedding --config configs/embedding.yaml
# Evaluasi:
python -m siakar_ml.evaluate
# Ekspor TFLite:
python -m siakar_ml.export_tflite
# Tes:
pytest
```

> **Catatan:** Cek tabel kompatibilitas resmi versi Python × TensorFlow sebelum memasang.  
> Dataset (ml/data/) **tidak** di-commit; unduh DigiFace-1M secara terpisah.

## Dokumen Referensi

Lihat `docs/project-kit/` — baca berurutan:
1. `DECISIONS.md` — keputusan final (menang atas semua dokumen lain)
2. `PRD.md` — lingkup dan kriteria penerimaan
3. `DESIGN.md` — arsitektur, skema DB, design token, layar
4. `API.md` — kontrak REST
5. `ML_SPEC.md` — spesifikasi model AI
6. `AGENTS.md` — aturan untuk AI coding agent
7. `TASKS.md` — backlog 4 minggu

## Aturan Penting

- Model wajah **dibangun dari nol** — dilarang pretrained (ML Kit, InsightFace, MobileNet, dll.)
- **Server adalah otoritas** untuk waktu, geofencing, ambang kecocokan
- Jangan commit: dataset, foto, `.env`, kunci/token, embedding
- Bahasa UI: **Indonesia**; nama kelas/fungsi: Inggris
