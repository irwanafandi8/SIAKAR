---
name: flutter-clean-feature
description: Membuat atau mengubah satu fitur Flutter SIAKAR dengan Clean Architecture dan Cubit (entity, repository, usecase, cubit, page, tes). Gunakan setiap kali menambah layar atau alur di folder mobile/.
---

# Skill: flutter-clean-feature

Baca dulu: `DECISIONS.md` (D-03, D-60), `API.md` (kontrak endpoint), `DESIGN.md` §4.1, §6–§8.

## Langkah

1. **Tentukan fitur dan ID** di PRD/TASKS (mis. FR-05). Cari kontrak endpoint di `API.md`. Jika belum ada, hentikan dan minta kontraknya dilengkapi.
2. **Buat struktur** di `lib/features/<fitur>/`:
   - `domain/entities/` (kelas murni Dart, `Equatable`), `domain/repositories/` (abstract), `domain/usecases/` (satu kelas = satu aksi, `call()`).
   - `data/models/` (DTO + `fromJson`, pemetaan ke entity), `data/datasources/` (Dio), `data/repositories/` (implementasi; ubah error jadi `Failure`).
   - `presentation/cubit/` (`<Fitur>Cubit` + `<Fitur>State`), `presentation/pages/`, `presentation/widgets/`.
3. **Aturan lapisan:** domain tidak mengimpor Flutter/Dio. Cubit hanya memanggil UseCase, tidak memanggil Dio langsung.
4. **State** minimal: `initial`, `loading`, `success(data)`, `failure(Failure)`. Satu cubit = satu layar utama.
5. **Error:** petakan `code` API → pesan UI di `core/error/` saja. Jangan menulis string error tersebar.
6. **Daftarkan DI** (`get_it`) dan **rute** (`go_router`) di `app/`.
7. **UI:** pakai token dan widget bersama dari `design/` (warna, radius, `StatusBadge`, `PrimaryButton`). Teks berbahasa Indonesia. Target sentuh ≥ 48 px.
8. **Tes:** unit test UseCase (repository di-mock) dan Cubit (`bloc_test` bila dipakai). Untuk fitur ML, tambahkan tes paritas (lihat skill `ml-train-evaluate-export`).
9. **Verifikasi:** `flutter analyze`, `flutter test`, lalu jalankan manual di ponsel bila menyentuh kamera/GPS dan tuliskan langkah ujinya.

## Larangan

- Jangan mengirim waktu klien untuk penentuan status. Jangan melakukan retry otomatis pada check-in/check-out.
- Jangan menaruh keputusan bisnis (radius, ambang, status) di klien; klien hanya menampilkan hasil server.
- Jangan membuat praproses gambar baru; pakai `core/ml/preprocess` yang mengikuti `preprocess.json`.
