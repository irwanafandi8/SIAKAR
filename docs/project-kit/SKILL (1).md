---
name: laravel-api-endpoint
description: Menambah endpoint REST di Laravel SIAKAR sesuai API.md (route, FormRequest, Service, Resource, respons seragam, tes Feature/Unit). Gunakan untuk setiap endpoint /api/v1 di folder admin/.
---

# Skill: laravel-api-endpoint

Baca dulu: `API.md` (kontrak, kode error, urutan pemeriksaan), `DECISIONS.md` (D-60..D-68), `DESIGN.md` §4.2 dan §5.

## Langkah

1. **Cocokkan dengan `API.md`**: path, metode, peran, field, kode error. Jika kontrak belum ada atau salah, ubah `API.md` dulu.
2. **Route** di `routes/api.php` dalam grup `v1`, middleware `auth:sanctum` dan `EnsureRole:<peran>`.
3. **FormRequest** untuk validasi. Kegagalan → 422 `VALIDATION_ERROR` lewat `ApiResponse`.
4. **Controller tipis**: panggil Service, kembalikan `ApiResponse::success(...)` atau lempar `DomainException` bertipe kode (mis. `FACE_MISMATCH`) yang diubah handler menjadi respons gagal seragam.
5. **Service** memegang logika (urutan pemeriksaan sesuai `API.md` §3.3 untuk check-in/out). Operasi multi-baris dibungkus `DB::transaction`.
6. **Resource** membentuk JSON persis seperti tipe di `API.md` §2.
7. **Model**: `$table`, `$primaryKey`, `$timestamps = false`; enum sebagai konstanta.
8. **Keamanan:** peran dicek di server; berkas di disk privat; embedding tidak masuk log/respons; password `bcrypt`.
9. **Tes:**
   - Unit: Haversine (jarak tahu), cosine (vektor tahu), status Hadir/Terlambat (batas toleransi tepat).
   - Feature: jalur sukses dan **setiap kode error** untuk endpoint itu.
10. **Verifikasi:** `php artisan test`; cek manual dengan klien HTTP; perbarui `API.md` bila kontrak berubah.

## Larangan

- Jangan memakai waktu dari klien untuk status. Jangan mengembalikan embedding. Jangan menyimpan baris absensi pada percobaan yang gagal.
- Jangan mengubah skema tanpa migrasi baru dan pembaruan `DESIGN.md` §5 / `DECISIONS.md` §4.1.
