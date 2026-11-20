# API.md — Kontrak REST API SIAKAR (Laravel ⇄ Flutter)

Mengikuti `DECISIONS.md` dan `PRD.md`. Kontrak ini adalah acuan **dua sisi**: backend mengimplementasikannya, mobile mengonsumsinya. Ubah kontrak di sini dulu, baru kode.

- Base URL: `{BASE}/api/v1`
- Auth: header `Authorization: Bearer <token>` (Laravel Sanctum), kecuali login.
- Format: JSON (`Content-Type: application/json`); endpoint dengan berkas memakai `multipart/form-data`.
- Zona waktu: **Asia/Jakarta**. Tanggal `YYYY-MM-DD`, waktu `HH:mm:ss`, datetime ISO 8601 dengan offset `+07:00`.
- Bahasa pesan: Indonesia.
- Fitur admin (web Blade) **tidak** lewat API ini.

## 1. Amplop Respons

Sukses:
```json
{ "success": true, "message": "OK", "data": { } }
```
Gagal:
```json
{ "success": false, "message": "Wajah tidak cocok.", "code": "FACE_MISMATCH", "errors": { "field": ["..."] } }
```
`errors` hanya ada untuk validasi (422). `code` selalu ada pada kegagalan.

### Kode HTTP dan kode kesalahan

| HTTP | `code` | Arti |
|---|---|---|
| 401 | `UNAUTHENTICATED` | Token tidak ada/kedaluwarsa |
| 401 | `INVALID_CREDENTIALS` | Username/password salah |
| 403 | `FORBIDDEN_ROLE` | Peran tidak berhak |
| 403 | `DEVICE_MISMATCH` | Perangkat berbeda dari yang terikat |
| 403 | `NOT_APPROVER` | Bukan atasan langsung pemohon |
| 404 | `NOT_FOUND` | Data tidak ditemukan |
| 409 | `ALREADY_CHECKED_IN` | Sudah absen masuk hari ini |
| 409 | `NOT_CHECKED_IN` | Belum absen masuk (untuk absen pulang) |
| 409 | `ALREADY_CHECKED_OUT` | Sudah absen pulang |
| 409 | `FACE_ALREADY_ENROLLED` | Wajah sudah terdaftar (gunakan `replace=true`) |
| 422 | `VALIDATION_ERROR` | Input tidak valid |
| 422 | `INVALID_EMBEDDING` | Embedding bentuknya salah (panjang ≠ 128, NaN, norma menyimpang) |
| 422 | `FACE_NOT_ENROLLED` | Wajah belum didaftarkan |
| 422 | `FACE_MISMATCH` | Skor kecocokan di bawah ambang |
| 422 | `LIVENESS_FAILED` | Klien melaporkan liveness gagal |
| 422 | `OUT_OF_RADIUS` | Di luar semua radius kantor |
| 422 | `NO_SCHEDULE` | Tidak ada jadwal pada hari itu |
| 422 | `HOLIDAY` | Hari libur |
| 429 | `TOO_MANY_ATTEMPTS` | Terlalu banyak percobaan (rate limit) |
| 500 | `SERVER_ERROR` | Kesalahan server |

## 2. Tipe Data Bersama

**Embedding**: larik 128 angka `float` (hasil L2-normalize dari model). Server memvalidasi panjang = 128, semua finite, dan norma ≈ 1 (toleransi kecil); selain itu `INVALID_EMBEDDING`.

**Pengguna (`user`)**
```json
{ "id_pengguna": 1, "id_karyawan": 10, "nama": "…", "nik": "…", "role": "karyawan|atasan|admin",
  "departemen": "…", "jabatan": "…", "face_enrolled": true }
```

**Absensi (`attendance`)**
```json
{ "id_absensi": 5, "tanggal": "2026-11-23", "jam_masuk": "07:58:10", "jam_pulang": null,
  "status": "hadir|terlambat|izin|sakit|cuti|alpa", "skor_wajah": 0.83,
  "lokasi": "Kantor Pusat", "keterangan": null }
```

**Pengajuan izin (`leave`)**
```json
{ "id_izin": 3, "jenis": "izin|sakit|cuti", "tanggal_mulai": "2026-11-25", "tanggal_selesai": "2026-11-26",
  "alasan": "…", "lampiran_url": null, "status": "menunggu|disetujui|ditolak",
  "pemohon": { "id_karyawan": 10, "nama": "…" }, "tanggal_pengajuan": "2026-11-23T09:00:00+07:00" }
```

## 3. Endpoint

### 3.1 Auth

**POST `/auth/login`** (publik)
```json
{ "username": "…", "password": "…", "device_id": "…" }
```
- `device_id`: ID perangkat dari klien (mis. identifier Android). Jika `pengguna.device_id` masih kosong → terikat saat login ini. Jika terisi dan berbeda → `DEVICE_MISMATCH`.
- 200 → `data`: `{ "token": "…", "user": <user> }`
- Error: `INVALID_CREDENTIALS`, `DEVICE_MISMATCH`, `VALIDATION_ERROR`, `TOO_MANY_ATTEMPTS`.
- Hanya role `karyawan` dan `atasan` yang boleh login lewat API mobile (admin lewat web).

**POST `/auth/logout`** → mencabut token saat ini. 200.

**GET `/me`** → `data`: `<user>`.

### 3.2 Wajah

**GET `/face/status`** → `data`: `{ "enrolled": true, "enrolled_at": "…" }`.

**POST `/face/enroll`** (`multipart/form-data`)

| Field | Tipe | Keterangan |
|---|---|---|
| `embeddings` | string JSON | Larik 3–5 embedding, mis. `[[…128…],[…128…],[…128…]]` |
| `photo` | file (jpeg/png) | Satu foto referensi (maks. 2 MB) |
| `replace` | boolean | `true` untuk mengganti data wajah yang sudah ada |

Server: validasi tiap embedding → rata-rata → L2-normalize → enkripsi → simpan `data_wajah` (aktif) + simpan foto di disk privat.
- 201 → `data`: `{ "enrolled": true }`.
- Error: `INVALID_EMBEDDING`, `FACE_ALREADY_ENROLLED`, `VALIDATION_ERROR`.

### 3.3 Absensi

**GET `/attendance/today`** → informasi untuk layar Beranda/Absen.
```json
{ "data": { "tanggal": "2026-11-23", "has_schedule": true, "is_holiday": false,
  "shift": { "nama": "Reguler", "jam_masuk": "08:00:00", "jam_pulang": "16:00:00", "toleransi_menit": 10 },
  "attendance": <attendance|null>,
  "locations": [ { "id_lokasi": 1, "nama": "Kantor Pusat", "latitude": -6.3277, "longitude": 108.3200, "radius_meter": 100 } ] } }
```
Dipakai klien untuk menampilkan jarak dan peta; **keputusan akhir tetap di server**.

**POST `/attendance/check-in`** dan **POST `/attendance/check-out`** (`multipart/form-data`)

| Field | Tipe | Keterangan |
|---|---|---|
| `embedding` | string JSON | Satu larik 128 angka |
| `latitude` | number | |
| `longitude` | number | |
| `liveness_passed` | boolean | Hasil liveness di klien (`true` bila fitur liveness belum aktif) |
| `photo` | file | Foto bukti (maks. 2 MB) |

Urutan pemeriksaan di server (berhenti di kegagalan pertama):
1. Peran/token → perangkat (`DEVICE_MISMATCH`)
2. Rate limit (`TOO_MANY_ATTEMPTS`)
3. Bentuk embedding (`INVALID_EMBEDDING`) dan `liveness_passed` (`LIVENESS_FAILED`)
4. Wajah terdaftar (`FACE_NOT_ENROLLED`)
5. Hari libur (`HOLIDAY`) → jadwal (`NO_SCHEDULE`)
6. Status absensi hari ini: check-in → `ALREADY_CHECKED_IN`; check-out → `NOT_CHECKED_IN` / `ALREADY_CHECKED_OUT`
7. Lokasi: Haversine ke semua `lokasi_kantor` (`OUT_OF_RADIUS`)
8. Kecocokan: `cosine ≥ face.threshold` (`FACE_MISMATCH`)
9. Simpan baris `absensi`; check-in menghitung status Hadir/Terlambat dari **waktu server**.

201 → `data`:
```json
{ "attendance": <attendance>, "similarity": 0.83, "distance_meter": 12.4, "status": "hadir" }
```
Pada kegagalan 422 `FACE_MISMATCH`/`OUT_OF_RADIUS`, `data` tambahan boleh berisi `similarity` / `distance_meter` untuk kebutuhan tampilan dan debugging.

> Kegagalan **tidak** menyimpan baris absensi. Percobaan gagal dicatat di log server untuk analisis, tanpa menyimpan embedding mentah.

**GET `/attendance/history?month=YYYY-MM`** → `data`: `{ "month": "2026-11", "items": [<attendance>…], "summary": { "hadir": 0, "terlambat": 0, "izin": 0, "sakit": 0, "cuti": 0, "alpa": 0 } }`.

### 3.4 Izin (karyawan)

**GET `/leaves?status=`** → daftar `leave` milik sendiri (filter opsional).

**POST `/leaves`** (`multipart/form-data`)

| Field | Tipe |
|---|---|
| `jenis` | `izin` \| `sakit` \| `cuti` |
| `tanggal_mulai`, `tanggal_selesai` | tanggal (selesai ≥ mulai) |
| `alasan` | string |
| `lampiran` | file opsional (jpeg/png/pdf, maks. 2 MB) |

201 → `data`: `<leave>` (status `menunggu`). Tidak boleh tumpang tindih dengan pengajuan `menunggu/disetujui` lain (`VALIDATION_ERROR`).

### 3.5 Persetujuan dan rekap (peran `atasan`)

**GET `/approvals?status=menunggu`** → daftar `leave` bawahan langsung.

**POST `/approvals/{id_izin}/approve`** dan **POST `/approvals/{id_izin}/reject`**
- Hanya atasan langsung (`NOT_APPROVER` selain itu); status harus `menunggu` (selain itu 409/422).
- `approve`: set `status=disetujui`, `id_penyetuju`, dan upsert `absensi` per tanggal dalam rentang (status = `jenis`) dalam satu transaksi.
- 200 → `data`: `<leave>` terbaru.

**GET `/team/recap?from=YYYY-MM-DD&to=YYYY-MM-DD`** → `data`: `{ "items": [ { "id_karyawan": 11, "nama": "…", "hadir": 0, "terlambat": 0, "izin": 0, "sakit": 0, "cuti": 0, "alpa": 0 } ] }`.

### 3.6 (Could) Absen manual

Hanya bila fitur ini dikerjakan (Q-6, PRD Could). Kontrak ditambahkan di sini saat dikerjakan.

## 4. Aturan Implementasi Backend

- Validasi dengan `FormRequest`; respons lewat satu helper/`ApiResponse` agar amplop konsisten.
- Logika bisnis di **Service class** (`FaceMatchService`, `GeofenceService`, `AttendanceService`, `LeaveService`), bukan di controller.
- Perhitungan Haversine dan cosine adalah fungsi murni yang diuji unit.
- Embedding terenkripsi dengan `Crypt`; jangan pernah dimasukkan ke log atau respons.
- Ambang dari `config('face.threshold')`; radius dari data `lokasi_kantor`.
- Rate limit: login dan check-in/check-out (mis. dengan `throttle`); nilai dikonfigurasi.
- Berkas privat di disk non-publik; akses melalui endpoint ber-otorisasi (admin), bukan URL publik.

## 5. Aturan Implementasi Mobile

- Satu `Dio` client dengan interceptor: tambah header token, ubah amplop menjadi `Failure` bertipe berdasarkan `code`.
- Pemetaan `code` → pesan UI ada di satu tempat (`core/error/`), bukan tersebar.
- Jangan mengirim waktu dari klien untuk penentuan status.
- Embedding dikirim sebagai larik JSON dari `Float32List` hasil TFLite; panjang 128.
- Timeout dan retry terbatas pada permintaan idempoten (GET); check-in/check-out **tanpa retry otomatis**.

## 6. Daftar Rute Ringkas

| Metode | Path | Peran |
|---|---|---|
| POST | `/auth/login` | publik |
| POST | `/auth/logout` | karyawan, atasan |
| GET | `/me` | karyawan, atasan |
| GET | `/face/status` | karyawan, atasan |
| POST | `/face/enroll` | karyawan, atasan |
| GET | `/attendance/today` | karyawan, atasan |
| POST | `/attendance/check-in` | karyawan, atasan |
| POST | `/attendance/check-out` | karyawan, atasan |
| GET | `/attendance/history` | karyawan, atasan |
| GET | `/leaves` | karyawan, atasan |
| POST | `/leaves` | karyawan, atasan |
| GET | `/approvals` | atasan |
| POST | `/approvals/{id}/approve` | atasan |
| POST | `/approvals/{id}/reject` | atasan |
| GET | `/team/recap` | atasan |
