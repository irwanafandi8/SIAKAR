---
name: laravel-admin-crud-blade
description: Membuat halaman admin CRUD/laporan dengan Blade dan Tailwind yang mengikuti design token SIAKAR (tabel, form, validasi, pagination, komponen bersama). Gunakan untuk semua halaman /admin.
---

# Skill: laravel-admin-crud-blade

Baca dulu: `DESIGN.md` §6 (token), §7 (komponen), §8.2 (halaman), `DECISIONS.md` D-06/D-07.

## Langkah

1. **Pastikan layout dan komponen ada**: `layouts/admin.blade.php` (sidebar navy, konten krem), komponen `x-card`, `x-table`, `x-form-field`, `x-status-badge`, `x-button`. Jika belum ada, buat dulu, jangan menyalin markup per halaman.
2. **Route resource** di `routes/web.php` dengan middleware `auth` + `EnsureRole:admin` (`/admin/...`).
3. **Controller** (`Admin\*Controller`) memakai `FormRequest`; operasi data lewat model atau Service yang sama dengan API (jangan menduplikasi aturan bisnis).
4. **Index:** tabel dengan pencarian dan `paginate()` server-side. Badge status dari `x-status-badge` (warna §6.1).
5. **Form:** label jelas, pesan error per field (`@error`), nilai lama (`old()`), konfirmasi sebelum hapus/nonaktif.
6. **Aksi khusus** (mis. reset wajah/perangkat pada karyawan, koreksi absensi dengan keterangan wajib) memakai `POST` terpisah dan menulis jejak yang jelas.
7. **Gaya:** hanya token dari `tailwind.config.js` (primary, navy, background, outline, tint). Jangan menambah warna di luar token.
8. **Tes:** `Feature` untuk akses (non-admin ditolak), validasi, dan operasi utama.

## Larangan

- Jangan memakai Filament atau paket panel admin. Jangan menaruh logika bisnis di Blade.
- Jangan menampilkan embedding; foto hanya lewat route ber-otorisasi.
