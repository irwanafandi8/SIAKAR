# Project Kit SIAKAR

Paket dokumen untuk mempercepat pembangunan aplikasi, model AI, dan laporan SIAKAR, termasuk untuk diarahkan ke AI coding agent.

## Isi dan urutan baca

| # | File | Fungsi |
|---|---|---|
| 1 | `DECISIONS.md` | Keputusan final (FIXED / PROPOSED / OPEN), pertanyaan terbuka, risiko, perubahan terhadap laporan |
| 2 | `PRD.md` | Lingkup MoSCoW, alur, aturan bisnis, kriteria penerimaan, skenario demo |
| 3 | `DESIGN.md` | Arsitektur, flowchart/sequence (Mermaid), struktur kode, skema DB, design token, layar |
| 4 | `API.md` | Kontrak REST Laravel ⇄ Flutter |
| 5 | `ML_SPEC.md` | Data, model dari nol, kontrak praproses dan ekspor TFLite, protokol evaluasi |
| 6 | `AGENTS.md` | Aturan untuk AI coding (salin ke root repo) |
| 7 | `TASKS.md` | Backlog 4 minggu dengan kriteria selesai |
| 8 | `skills/*/SKILL.md` | Panduan tugas berulang: Flutter, API Laravel, admin Blade, ML, penulisan laporan |

## Cara memakai dengan AI coding agent

1. Salin `AGENTS.md` ke root repo; salin folder `docs/project-kit/` ke `docs/`.
2. Beri satu tugas per sesi, sebut ID dari `TASKS.md` (mis. "kerjakan T-213").
3. Minta agent membaca `DECISIONS.md`, bagian PRD/API/DESIGN yang relevan, dan skill yang cocok sebelum menulis kode.
4. Minta ringkasan di akhir: perubahan, cara verifikasi, asumsi, yang belum dikerjakan.
5. Jika keputusan berubah, ubah `DECISIONS.md` lebih dulu.

## Yang masih terbuka (ringkas)

Lihat `DECISIONS.md` §6: fallback liveness (Q-1), sumber data non-wajah dan liveness (Q-2), jumlah identitas subset (Q-3), target akurasi internal (Q-4), status baseline klasik (Q-5), absen manual (Q-6), admin berbasis Flutter atau tidak (Q-7).

## Catatan penting

- Semua item **[PROPOSED]** adalah default dari diskusi dan perlu dikonfirmasi kelompok.
- Nama pustaka dan perintah di dokumen adalah usulan; cek versi dan kompatibilitas di mesin masing-masing.
- Angka target (akurasi, latensi) sengaja belum ditetapkan; ukur dulu.
