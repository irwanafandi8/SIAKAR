# AGENTS.md — Aturan untuk AI Coding Agent (SIAKAR)

Salin file ini ke **root repositori** sebagai `AGENTS.md` (atau `CLAUDE.md`, atau aturan alat lain; isinya sama). Dokumen rujukan ada di `docs/project-kit/`.

## 1. Baca dulu (urutan)

1. `docs/project-kit/DECISIONS.md` — keputusan final. **Menang atas semua dokumen lain.**
2. `docs/project-kit/PRD.md` — apa yang dibangun dan kriteria penerimaan.
3. Sesuai tugas: `DESIGN.md` (arsitektur, skema, UI), `API.md` (kontrak), `ML_SPEC.md` (model dan praproses).
4. `docs/project-kit/TASKS.md` — tugas aktif dan definisi selesai.

Jika tugas bertentangan dengan dokumen, **berhenti dan laporkan konfliknya**; jangan memilih sendiri. Jika dokumen belum menjawab (status OPEN), pilih opsi aman yang tertulis, dan catat asumsi di akhir jawaban.

## 2. Struktur repositori

```
mobile/   Flutter (Clean Architecture + Cubit)
admin/    Laravel (API /api/v1 + web Blade) + MySQL
ml/       Python (TensorFlow/Keras): data, latih, evaluasi, ekspor TFLite
docs/     laporan, project-kit
```

## 3. Aturan keras (tidak boleh dilanggar)

1. **Model dari nol.** Dilarang memakai bobot pretrained atau model pihak ketiga untuk deteksi wajah, embedding, atau liveness (termasuk ML Kit, InsightFace, DeepFace, `face_recognition`, Haar/DNN bawaan OpenCV, MobileNet/ResNet pretrained). Kode loss/arsitektur boleh ditulis sendiri.
2. **Tanpa Colab/notebook cloud.** Pelatihan di Python lokal pada `ml/`.
3. **Jangan mengubah skema DB, kontrak API, atau kontrak ekspor model** tanpa mengubah `DECISIONS.md`/`API.md`/`ML_SPEC.md` terlebih dahulu dan menyebutnya di ringkasan.
4. **Praproses hanya punya satu spesifikasi** (`ML_SPEC.md` §4, `ml/artifacts/preprocess.json`). Jangan menulis variasi sendiri di Dart atau Python.
5. **Server adalah otoritas** (waktu, geofencing, shift, status, ambang). Klien hanya menampilkan.
6. **Jangan commit**: dataset, foto, model besar yang tidak diperlukan, `.env`, kunci/token, kredensial, data pribadi. Jangan mencatat embedding atau password di log.
7. Admin memakai **Blade** (bukan Filament, bukan Flutter web). Tampilan memakai token di `DESIGN.md` §6.
8. Bahasa UI: Indonesia. Nama kode: Inggris untuk kelas/fungsi; nama tabel/kolom mengikuti kamus data (Indonesia).
9. Jangan menambah dependensi besar tanpa alasan tertulis. Waktu proyek singkat: pilih solusi paling sederhana yang memenuhi kriteria penerimaan.
10. Jangan menyatakan "selesai" tanpa menjalankan verifikasi (bagian 5).

## 4. Perintah (sesuaikan bila berbeda di mesin; konfirmasi sebelum mengandalkan)

| Area | Perintah |
|---|---|
| Flutter | `cd mobile && flutter pub get` · `flutter analyze` · `flutter test` · `flutter run` |
| Laravel | `cd admin && composer install` · `php artisan migrate --seed` · `php artisan test` · `php artisan serve` |
| Aset admin | `npm install` · `npm run dev` / `npm run build` |
| ML | `cd ml && python -m venv .venv` · aktifkan venv · `pip install -r requirements.txt` · `python -m siakar_ml.train_embedding --config configs/embedding.yaml` · `python -m siakar_ml.evaluate ...` · `python -m siakar_ml.export_tflite ...` · `pytest` |

Versi Python harus yang didukung oleh versi TensorFlow yang dipilih; cek tabel kompatibilitas resmi sebelum memasang.

## 5. Definisi selesai (tiap perubahan)

- [ ] Memenuhi kriteria penerimaan terkait di `PRD.md`.
- [ ] Kode lolos linter/analyzer; tes relevan ditulis dan lulus.
- [ ] Tidak ada rahasia/data pribadi di diff.
- [ ] Dokumen rujukan diperbarui bila ada perubahan keputusan/kontrak.
- [ ] Ringkasan berisi: apa yang diubah, cara memverifikasi, asumsi, dan hal yang belum dikerjakan.

## 6. Konvensi kode

**Flutter:** `presentation → domain ← data`; domain tanpa Flutter/Dio; Cubit hanya memanggil UseCase; state `initial/loading/success/failure`; DI dengan `get_it`; routing `go_router`; kegagalan jaringan dipetakan ke `Failure` bertipe di `core/error`; tema dari `design/`.
**Laravel:** controller tipis → `FormRequest` → `Service`; respons lewat `ApiResponse`; resource untuk bentuk JSON; model memakai `$table/$primaryKey/$timestamps=false`; transaksi DB untuk operasi multi-baris (mis. persetujuan izin); tes `Feature` untuk tiap endpoint, tes `Unit` untuk Haversine dan cosine.
**Python:** modul di `src/siakar_ml/`; konfigurasi lewat YAML; seed dikunci; tidak memuat seluruh dataset ke memori; simpan checkpoint tiap epoch; tes untuk praproses, split, dan metrik.

## 6.1 Skills

Panduan tugas berulang ada di `docs/project-kit/skills/<nama>/SKILL.md`. Baca skill yang relevan sebelum mengerjakan:
`flutter-clean-feature`, `laravel-api-endpoint`, `laravel-admin-crud-blade`, `ml-train-evaluate-export`, `write-report-section`.

## 7. Cara bekerja

- Kerjakan **satu tugas TASKS per sesi**; sebut ID tugasnya.
- Kecil dan terverifikasi lebih baik daripada besar dan belum dicoba.
- Untuk bagian berisiko (praproses lintas bahasa, ekspor TFLite, akses kamera/GPS), buat uji kecil lebih dulu sebelum membangun fitur di atasnya.
- Jika tugas membutuhkan perangkat fisik (kamera, GPS), jelaskan langkah uji manual untuk pengguna.
