# Laporan Benchmark 1 Epoch CNN Embedding SIAKAR (T-107)

- **Tanggal Pengukuran**: `2026-11-25T09:29:35.874003`
- **Ukuran Input Diuji**: `112x112x3`
- **Jumlah Kelas (Kelompok A)**: `350`
- **Jumlah Gambar Diproses**: `18900` (591 step)
- **Parameter Backbone**: `1,198,560` (~`4.572 MB` float32 `.tflite`)

## 1. Hasil Waktu & Memori

| Metrik | Nilai |
|---|---|
| Waktu total 1 epoch (wall-clock) | `69.981 detik` |
| Waktu langkah ke-1 (warmup graf) | `2.019 detik` |
| Rata-rata waktu per batch (steady-state) | `114.03 ms` |
| Throughput steady-state | `280.45 gambar/detik` |
| RAM proses sebelum latihan | `276.81 MB` |
| Puncak RAM proses (Peak Working Set / RSS) | `551.44 MB` |
| Loss awal → akhir epoch 1 | `5.8735 → 5.3604` |

## 2. Proyeksi Waktu Latihan Penuh (30 Epoch, Kelompok A = 70% × 54 gambar)

| `n_identities` | Identitas Latih (A) | Gambar Latih | `input_size` | Est. Gambar/dtk | Est. 1 Epoch (dtk) | Est. 30 Epoch (menit) |
|---|---|---|---|---|---|---|
| 1000 | 700 | 37800 | 112x112 | 280.45 | 134.8 | 67.4 |
| 500 | 350 | 18900 | 112x112 | 280.45 | 67.4 | 33.7 |
| 500 | 350 | 18900 | 96x96 | 381.73 | 49.5 | 24.8 |
| 300 | 210 | 11340 | 96x96 | 381.73 | 29.7 | 14.9 |
| 300 | 210 | 11340 | 64x64 | 858.89 | 13.2 | 6.6 |
| 200 | 140 | 7560 | 64x64 | 858.89 | 8.8 | 4.4 |

## 3. Usulan Hyperparameter (Untuk Dicatat ke `DECISIONS.md` D-46)

- **Usulan `n_identities`**: `1000`
- **Usulan `input_size`**: `112`
- **Usulan `batch_size`**: `32`
- **Alasan**: Berdasarkan kecepatan ukur aktual 280.45 gambar/detik pada input 112x112 (puncak RAM proses ~551.4 MB), konfigurasi n_identities=1000 (37800 citra latih Kelompok A) dengan input_size=112 dan batch_size=32 membutuhkan ~134.8 detik/epoch (~67.4 menit untuk 30 epoch), sehingga aman dijalankan di CPU laptop RAM 8 GB.
