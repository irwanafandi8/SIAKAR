---
name: write-report-section
description: Menurunkan bagian laporan/proposal (PM2, AI, MPPL, progres mingguan) dari PRD, DESIGN, API, dan ML_SPEC agar konsisten dan tidak menulis ulang dari nol. Gunakan saat menyusun dokumen tugas.
---

# Skill: write-report-section

Sumber kebenaran: `DECISIONS.md`. Jangan menulis fakta yang bertentangan dengannya.

## Peta sumber → dokumen

| Dokumen tugas | Ambil dari |
|---|---|
| **Proposal PM2** (3–5 hal, PDF): judul, latar belakang, tujuan/fitur, teknologi, arsitektur, flowchart, rencana | PRD §1–§4, DECISIONS §1–§2, DESIGN §1–§3 (diagram Mermaid → ekspor gambar), TASKS (rencana) |
| **Laporan AI**: pipeline per tahap (konsep, kode, hasil, analisis) | ML_SPEC §3–§8, `ml/reports/` |
| **Laporan MPPL/analisis** | Laporan analisis yang sudah ada + DECISIONS §5 (perubahan wajib) |
| **Laporan progres mingguan** | TASKS (status tugas minggu itu), hasil terbaru, kendala |

## Langkah

1. Tentukan dokumen dan batasnya (mis. proposal PM2: 3–5 halaman, PDF; isi harus rencana implementasi, bukan sekadar nama teknologi).
2. Salin/ringkas dari sumber pada peta, jangan mengarang. Jika data belum ada (angka hasil model, ukuran dataset), tulis **"belum diukur"**, jangan memperkirakan.
3. Gunakan istilah yang sama dengan materi kuliah dosen terkait.
4. Cantumkan **keterbatasan** secara terang (dataset sintetis, selisih domain, liveness sederhana, embedding dihitung di klien).
5. Periksa konsistensi: nama teknologi, arsitektur, dan angka sama di semua dokumen.
6. Setiap klaim akurasi harus punya rujukan ke berkas hasil di `ml/reports/`.

## Larangan

- Jangan menuliskan target akurasi sebagai hasil. Jangan menyebut model pretrained sebagai model yang dipakai.
- Jangan memakai data kuesioner ilustratif sebagai dasar analisis AI; kuesioner hanya konteks kebutuhan (MPPL).
