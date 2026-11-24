<?php

namespace Tests\Feature;

use App\Models\Absensi;
use App\Models\DataWajah;
use App\Models\Departemen;
use App\Models\HariLibur;
use App\Models\Jabatan;
use App\Models\JadwalKaryawan;
use App\Models\Karyawan;
use App\Models\LokasiKantor;
use App\Models\Pengguna;
use App\Models\Shift;
use App\Services\FaceMatchService;
use Carbon\Carbon;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Storage;
use Tests\TestCase;

class AttendanceTest extends TestCase
{
    use RefreshDatabase;

    private Karyawan $karyawan;
    private Pengguna $karyawanUser;
    private Karyawan $atasan;
    private Pengguna $atasanUser;
    private Pengguna $adminUser;
    private Shift $shiftReguler;
    private LokasiKantor $lokasiPusat;
    private LokasiKantor $lokasiCabang;
    private string $token;
    private FaceMatchService $faceMatchService;

    protected function setUp(): void
    {
        parent::setUp();

        Storage::fake('private');
        Storage::fake('public');

        config([
            'face.threshold'     => 0.75,
            'face.embedding_dim' => 128,
            'face.max_attempts'  => 10,
            'face.storage_disk'  => 'private',
        ]);

        Carbon::setTestNow(Carbon::create(2026, 11, 24, 7, 55, 0, 'Asia/Jakarta'));

        $this->faceMatchService = app(FaceMatchService::class);

        $dept = Departemen::create(['nama_departemen' => 'Teknologi Informasi']);
        $jabStaff = Jabatan::create(['nama_jabatan' => 'Software Engineer']);
        $jabMgr = Jabatan::create(['nama_jabatan' => 'IT Manager']);

        $this->atasan = Karyawan::create([
            'nik'           => 'ATS-100',
            'nama'          => 'Atasan Uji',
            'jenis_kelamin' => 'L',
            'tanggal_lahir' => '1988-05-10',
            'tanggal_masuk' => '2020-01-01',
            'id_departemen' => $dept->id_departemen,
            'id_jabatan'    => $jabMgr->id_jabatan,
            'status_aktif'  => true,
        ]);

        $this->karyawan = Karyawan::create([
            'nik'           => 'KRY-100',
            'nama'          => 'Karyawan Uji',
            'jenis_kelamin' => 'P',
            'tanggal_lahir' => '1997-04-12',
            'tanggal_masuk' => '2023-01-01',
            'id_departemen' => $dept->id_departemen,
            'id_jabatan'    => $jabStaff->id_jabatan,
            'id_atasan'     => $this->atasan->id_karyawan,
            'status_aktif'  => true,
        ]);

        $this->karyawanUser = Pengguna::create([
            'id_karyawan'   => $this->karyawan->id_karyawan,
            'username'      => 'karyawan_uji',
            'password_hash' => Hash::make('secret123'),
            'role'          => Pengguna::ROLE_KARYAWAN,
            'device_id'     => 'device-kry-100',
        ]);

        $this->atasanUser = Pengguna::create([
            'id_karyawan'   => $this->atasan->id_karyawan,
            'username'      => 'atasan_uji',
            'password_hash' => Hash::make('secret123'),
            'role'          => Pengguna::ROLE_ATASAN,
            'device_id'     => 'device-ats-100',
        ]);

        $this->adminUser = Pengguna::create([
            'id_karyawan'   => null,
            'username'      => 'admin_uji',
            'password_hash' => Hash::make('secret123'),
            'role'          => Pengguna::ROLE_ADMIN,
            'device_id'     => null,
        ]);

        $this->shiftReguler = Shift::create([
            'nama_shift'      => 'Reguler',
            'jam_masuk'       => '08:00:00',
            'jam_pulang'      => '16:00:00',
            'toleransi_menit' => 10,
        ]);

        $this->lokasiPusat = LokasiKantor::create([
            'nama_lokasi'  => 'Kantor Pusat',
            'latitude'     => -6.32770000,
            'longitude'    => 108.32000000,
            'radius_meter' => 100,
        ]);

        $this->lokasiCabang = LokasiKantor::create([
            'nama_lokasi'  => 'Kantor Cabang',
            'latitude'     => -6.33000000,
            'longitude'    => 108.32500000,
            'radius_meter' => 150,
        ]);

        JadwalKaryawan::create([
            'id_karyawan' => $this->karyawan->id_karyawan,
            'id_shift'    => $this->shiftReguler->id_shift,
            'tanggal'     => '2026-11-24',
        ]);

        $this->enrollDefaultFace($this->karyawan);

        $this->token = $this->karyawanUser->createToken('test-mobile')->plainTextToken;
    }

    protected function tearDown(): void
    {
        Carbon::setTestNow();
        parent::tearDown();
    }

    /**
     * Buat vektor 128-d ter-normalisasi L2 pada basis indeks tertentu.
     *
     * @return list<float>
     */
    private function makeBasisEmbedding(int $basisIndex = 0): array
    {
        $vec = array_fill(0, 128, 0.0);
        $vec[$basisIndex] = 1.0;

        return $vec;
    }

    private function enrollDefaultFace(Karyawan $karyawan, int $basisIndex = 0): DataWajah
    {
        $vector = $this->makeBasisEmbedding($basisIndex);

        return DataWajah::create([
            'id_karyawan'    => $karyawan->id_karyawan,
            'embedding'      => $this->faceMatchService->encryptEmbedding($vector),
            'foto_referensi' => "faces/{$karyawan->id_karyawan}/ref.png",
            'tanggal_daftar' => Carbon::now('Asia/Jakarta'),
            'aktif'          => true,
        ]);
    }

    private function fakePhoto(string $filename = 'bukti.png'): UploadedFile
    {
        // Minimal valid 1x1 PNG agar tidak bergantung pada ekstensi GD di semua lingkungan
        $pngBytes = base64_decode(
            'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==',
            true
        );

        return UploadedFile::fake()->createWithContent($filename, $pngBytes);
    }

    /**
     * @param  array<string, mixed>  $overrides
     * @return array<string, mixed>
     */
    private function validPayload(array $overrides = []): array
    {
        return array_merge([
            'embedding'       => json_encode($this->makeBasisEmbedding(0)),
            'latitude'        => -6.32770000,
            'longitude'       => 108.32000000,
            'liveness_passed' => 'true',
            'photo'           => $this->fakePhoto(),
        ], $overrides);
    }

    public function test_unauthenticated_requests_return_401(): void
    {
        $this->getJson('/api/v1/attendance/today')
            ->assertStatus(401)
            ->assertJson(['success' => false, 'code' => 'UNAUTHENTICATED']);

        $this->postJson('/api/v1/attendance/check-in', [])
            ->assertStatus(401)
            ->assertJson(['success' => false, 'code' => 'UNAUTHENTICATED']);

        $this->postJson('/api/v1/attendance/check-out', [])
            ->assertStatus(401)
            ->assertJson(['success' => false, 'code' => 'UNAUTHENTICATED']);

        $this->getJson('/api/v1/attendance/history')
            ->assertStatus(401)
            ->assertJson(['success' => false, 'code' => 'UNAUTHENTICATED']);
    }

    public function test_admin_role_is_forbidden_403(): void
    {
        $adminToken = $this->adminUser->createToken('admin-token')->plainTextToken;

        $this->withHeader('Authorization', "Bearer {$adminToken}")
            ->getJson('/api/v1/attendance/today')
            ->assertStatus(403)
            ->assertJson(['success' => false, 'code' => 'FORBIDDEN_ROLE']);

        $this->withHeader('Authorization', "Bearer {$adminToken}")
            ->post('/api/v1/attendance/check-in', $this->validPayload(), ['Accept' => 'application/json'])
            ->assertStatus(403)
            ->assertJson(['success' => false, 'code' => 'FORBIDDEN_ROLE']);
    }

    public function test_user_without_karyawan_profile_returns_404_not_found(): void
    {
        $orphanUser = Pengguna::create([
            'id_karyawan'   => null,
            'username'      => 'orphan_karyawan',
            'password_hash' => Hash::make('secret123'),
            'role'          => Pengguna::ROLE_KARYAWAN,
            'device_id'     => 'device-orphan',
        ]);
        $orphanToken = $orphanUser->createToken('orphan-token')->plainTextToken;

        $this->withHeader('Authorization', "Bearer {$orphanToken}")
            ->getJson('/api/v1/attendance/today')
            ->assertStatus(404)
            ->assertJson(['success' => false, 'code' => 'NOT_FOUND']);
    }

    public function test_today_endpoint_returns_schedule_locations_and_null_attendance_initially(): void
    {
        $response = $this->withHeader('Authorization', "Bearer {$this->token}")
            ->getJson('/api/v1/attendance/today');

        $response->assertStatus(200)
            ->assertJson([
                'success' => true,
                'data'    => [
                    'tanggal'      => '2026-11-24',
                    'has_schedule' => true,
                    'is_holiday'   => false,
                    'shift'        => [
                        'nama'            => 'Reguler',
                        'jam_masuk'       => '08:00:00',
                        'jam_pulang'      => '16:00:00',
                        'toleransi_menit' => 10,
                    ],
                    'attendance'   => null,
                ],
            ])
            ->assertJsonCount(2, 'data.locations');
    }

    public function test_check_in_on_time_succeeds_saves_private_photo_and_ignores_client_time(): void
    {
        Carbon::setTestNow(Carbon::create(2026, 11, 24, 7, 58, 10, 'Asia/Jakarta'));

        $payload = $this->validPayload([
            // Kirim waktu palsu dari klien untuk memastikan server mengabaikannya
            'jam_masuk' => '12:00:00',
            'tanggal'   => '2026-01-01',
        ]);

        $response = $this->withHeader('Authorization', "Bearer {$this->token}")
            ->post('/api/v1/attendance/check-in', $payload, ['Accept' => 'application/json']);

        $response->assertStatus(201)
            ->assertJson([
                'success' => true,
                'data'    => [
                    'status'         => 'hadir',
                    'similarity'     => 1,
                    'distance_meter' => 0,
                    'attendance'     => [
                        'tanggal'    => '2026-11-24',
                        'jam_masuk'  => '07:58:10',
                        'jam_pulang' => null,
                        'status'     => 'hadir',
                        'lokasi'     => 'Kantor Pusat',
                    ],
                ],
            ])
            ->assertJsonMissingPath('data.embedding')
            ->assertJsonMissingPath('data.attendance.embedding');

        $absensi = Absensi::where('id_karyawan', $this->karyawan->id_karyawan)->first();
        $this->assertNotNull($absensi);
        $this->assertSame('07:58:10', substr((string) $absensi->jam_masuk, 0, 8));
        $this->assertSame($this->lokasiPusat->id_lokasi, $absensi->id_lokasi);
        $this->assertNotNull($absensi->foto_masuk);
        Storage::disk('private')->assertExists($absensi->foto_masuk);
        $this->assertEmpty(Storage::disk('public')->allFiles());
    }

    public function test_check_in_past_tolerance_marks_status_terlambat_and_check_out_preserves_it(): void
    {
        // Shift 08:00:00 + toleransi 10 menit -> 08:10:01 adalah terlambat
        Carbon::setTestNow(Carbon::create(2026, 11, 24, 8, 10, 1, 'Asia/Jakarta'));

        $checkInResponse = $this->withHeader('Authorization', "Bearer {$this->token}")
            ->post('/api/v1/attendance/check-in', $this->validPayload(), ['Accept' => 'application/json']);

        $checkInResponse->assertStatus(201)
            ->assertJson([
                'success' => true,
                'data'    => [
                    'status'     => 'terlambat',
                    'attendance' => [
                        'jam_masuk' => '08:10:01',
                        'status'    => 'terlambat',
                    ],
                ],
            ]);

        // Absen pulang sore hari pada hari yang sama
        Carbon::setTestNow(Carbon::create(2026, 11, 24, 16, 5, 30, 'Asia/Jakarta'));

        $checkOutResponse = $this->withHeader('Authorization', "Bearer {$this->token}")
            ->post('/api/v1/attendance/check-out', $this->validPayload(), ['Accept' => 'application/json']);

        $checkOutResponse->assertStatus(201)
            ->assertJson([
                'success' => true,
                'data'    => [
                    'status'     => 'terlambat',
                    'attendance' => [
                        'tanggal'    => '2026-11-24',
                        'jam_masuk'  => '08:10:01',
                        'jam_pulang' => '16:05:30',
                        'status'     => 'terlambat',
                    ],
                ],
            ]);

        $this->assertSame(1, Absensi::where('id_karyawan', $this->karyawan->id_karyawan)->count());
        $absensi = Absensi::where('id_karyawan', $this->karyawan->id_karyawan)->firstOrFail();
        Storage::disk('private')->assertExists($absensi->foto_pulang);
    }

    public function test_atasan_role_can_check_in_and_selects_nearest_valid_location(): void
    {
        JadwalKaryawan::create([
            'id_karyawan' => $this->atasan->id_karyawan,
            'id_shift'    => $this->shiftReguler->id_shift,
            'tanggal'     => '2026-11-24',
        ]);
        $this->enrollDefaultFace($this->atasan, 5);
        $atasanToken = $this->atasanUser->createToken('atasan-mobile')->plainTextToken;

        // Tambahkan lokasi overlapping yang lebih jauh agar memastikan pemilihan lokasi TERDEKAT yang lolos
        LokasiKantor::create([
            'nama_lokasi'  => 'Area Kompleks Besar',
            'latitude'     => -6.33100000,
            'longitude'    => 108.32500000,
            'radius_meter' => 500,
        ]);

        // Koordinat tepat di Kantor Cabang (-6.3300, 108.3250) -> jarak ke Kantor Cabang = 0m, ke Kompleks Besar ~111m
        $payload = $this->validPayload([
            'embedding' => json_encode($this->makeBasisEmbedding(5)),
            'latitude'  => -6.33000000,
            'longitude' => 108.32500000,
        ]);

        $response = $this->withHeader('Authorization', "Bearer {$atasanToken}")
            ->post('/api/v1/attendance/check-in', $payload, ['Accept' => 'application/json']);

        $response->assertStatus(201)
            ->assertJsonPath('data.attendance.lokasi', 'Kantor Cabang');
    }

    public function test_device_mismatch_returns_403_when_device_differs_or_unbound(): void
    {
        // Kasus 1: Mengirimkan device_id berbeda dari yang terikat
        $this->withHeader('Authorization', "Bearer {$this->token}")
            ->post('/api/v1/attendance/check-in', $this->validPayload(['device_id' => 'other-phone']), ['Accept' => 'application/json'])
            ->assertStatus(403)
            ->assertJson(['success' => false, 'code' => 'DEVICE_MISMATCH']);

        // Kasus 2: Admin me-reset device_id di DB menjadi null
        $this->karyawanUser->update(['device_id' => null]);
        $this->app['auth']->forgetGuards();

        $this->withHeader('Authorization', "Bearer {$this->token}")
            ->post('/api/v1/attendance/check-in', $this->validPayload(), ['Accept' => 'application/json'])
            ->assertStatus(403)
            ->assertJson(['success' => false, 'code' => 'DEVICE_MISMATCH']);

        $this->assertSame(0, Absensi::count());
    }

    public function test_rate_limit_returns_429_too_many_attempts(): void
    {
        config(['face.max_attempts' => 2]);

        for ($i = 0; $i < 2; $i++) {
            $this->withHeader('Authorization', "Bearer {$this->token}")
                ->post('/api/v1/attendance/check-in', $this->validPayload(['liveness_passed' => 'false']), ['Accept' => 'application/json'])
                ->assertStatus(422);
        }

        $this->withHeader('Authorization', "Bearer {$this->token}")
            ->post('/api/v1/attendance/check-in', $this->validPayload(), ['Accept' => 'application/json'])
            ->assertStatus(429)
            ->assertJson(['success' => false, 'code' => 'TOO_MANY_ATTEMPTS']);
    }

    public function test_validation_error_returns_422_when_required_fields_invalid(): void
    {
        $this->withHeader('Authorization', "Bearer {$this->token}")
            ->post('/api/v1/attendance/check-in', ['latitude' => 200], ['Accept' => 'application/json'])
            ->assertStatus(422)
            ->assertJson(['success' => false, 'code' => 'VALIDATION_ERROR'])
            ->assertJsonStructure(['errors' => ['embedding', 'latitude', 'longitude', 'liveness_passed', 'photo']]);
    }

    public function test_invalid_embedding_returns_422(): void
    {
        // Panjang bukan 128
        $shortPayload = $this->validPayload(['embedding' => json_encode([1.0, 0.0, 0.0])]);

        $this->withHeader('Authorization', "Bearer {$this->token}")
            ->post('/api/v1/attendance/check-in', $shortPayload, ['Accept' => 'application/json'])
            ->assertStatus(422)
            ->assertJson(['success' => false, 'code' => 'INVALID_EMBEDDING']);

        // Norma menyimpang jauh dari 1
        $unnormalizedPayload = $this->validPayload(['embedding' => json_encode(array_fill(0, 128, 1.0))]);

        $this->withHeader('Authorization', "Bearer {$this->token}")
            ->post('/api/v1/attendance/check-in', $unnormalizedPayload, ['Accept' => 'application/json'])
            ->assertStatus(422)
            ->assertJson(['success' => false, 'code' => 'INVALID_EMBEDDING']);

        $this->assertSame(0, Absensi::count());
    }

    public function test_liveness_failed_returns_422(): void
    {
        $this->withHeader('Authorization', "Bearer {$this->token}")
            ->post('/api/v1/attendance/check-in', $this->validPayload(['liveness_passed' => 'false']), ['Accept' => 'application/json'])
            ->assertStatus(422)
            ->assertJson(['success' => false, 'code' => 'LIVENESS_FAILED']);

        $this->assertSame(0, Absensi::count());
    }

    public function test_face_not_enrolled_returns_422(): void
    {
        DataWajah::where('id_karyawan', $this->karyawan->id_karyawan)->delete();

        $this->withHeader('Authorization', "Bearer {$this->token}")
            ->post('/api/v1/attendance/check-in', $this->validPayload(), ['Accept' => 'application/json'])
            ->assertStatus(422)
            ->assertJson(['success' => false, 'code' => 'FACE_NOT_ENROLLED']);

        $this->assertSame(0, Absensi::count());
    }

    public function test_holiday_returns_422_before_schedule_check(): void
    {
        HariLibur::create([
            'tanggal'    => '2026-11-24',
            'keterangan' => 'Libur Uji Nasional',
        ]);

        // Bahkan jika jadwal dihapus, sesuai urutan API.md §3.3 langkah 5: HOLIDAY diperiksa sebelum NO_SCHEDULE
        JadwalKaryawan::where('id_karyawan', $this->karyawan->id_karyawan)->delete();

        $this->withHeader('Authorization', "Bearer {$this->token}")
            ->post('/api/v1/attendance/check-in', $this->validPayload(), ['Accept' => 'application/json'])
            ->assertStatus(422)
            ->assertJson(['success' => false, 'code' => 'HOLIDAY']);

        $this->assertSame(0, Absensi::count());
    }

    public function test_no_schedule_returns_422(): void
    {
        JadwalKaryawan::where('id_karyawan', $this->karyawan->id_karyawan)->delete();

        $this->withHeader('Authorization', "Bearer {$this->token}")
            ->post('/api/v1/attendance/check-in', $this->validPayload(), ['Accept' => 'application/json'])
            ->assertStatus(422)
            ->assertJson(['success' => false, 'code' => 'NO_SCHEDULE']);

        $this->assertSame(0, Absensi::count());
    }

    public function test_already_checked_in_not_checked_in_and_already_checked_out_return_409(): void
    {
        // 1. Absen pulang sebelum absen masuk -> 409 NOT_CHECKED_IN
        $this->withHeader('Authorization', "Bearer {$this->token}")
            ->post('/api/v1/attendance/check-out', $this->validPayload(), ['Accept' => 'application/json'])
            ->assertStatus(409)
            ->assertJson(['success' => false, 'code' => 'NOT_CHECKED_IN']);

        // 2. Absen masuk pertama kali -> 201
        $this->withHeader('Authorization', "Bearer {$this->token}")
            ->post('/api/v1/attendance/check-in', $this->validPayload(), ['Accept' => 'application/json'])
            ->assertStatus(201);

        // 3. Absen masuk kedua kali di hari yang sama -> 409 ALREADY_CHECKED_IN
        $this->withHeader('Authorization', "Bearer {$this->token}")
            ->post('/api/v1/attendance/check-in', $this->validPayload(), ['Accept' => 'application/json'])
            ->assertStatus(409)
            ->assertJson(['success' => false, 'code' => 'ALREADY_CHECKED_IN']);

        // 4. Absen pulang pertama kali -> 201
        Carbon::setTestNow(Carbon::create(2026, 11, 24, 16, 10, 0, 'Asia/Jakarta'));
        $this->withHeader('Authorization', "Bearer {$this->token}")
            ->post('/api/v1/attendance/check-out', $this->validPayload(), ['Accept' => 'application/json'])
            ->assertStatus(201);

        // 5. Absen pulang kedua kali -> 409 ALREADY_CHECKED_OUT
        $this->withHeader('Authorization', "Bearer {$this->token}")
            ->post('/api/v1/attendance/check-out', $this->validPayload(), ['Accept' => 'application/json'])
            ->assertStatus(409)
            ->assertJson(['success' => false, 'code' => 'ALREADY_CHECKED_OUT']);
    }

    public function test_out_of_radius_returns_422_with_distance_and_does_not_save_row(): void
    {
        // Koordinat jauh di Jakarta (~190 km dari Indramayu)
        $farPayload = $this->validPayload([
            'latitude'  => -6.20000000,
            'longitude' => 106.81666600,
        ]);

        $response = $this->withHeader('Authorization', "Bearer {$this->token}")
            ->post('/api/v1/attendance/check-in', $farPayload, ['Accept' => 'application/json']);

        $response->assertStatus(422)
            ->assertJson([
                'success' => false,
                'code'    => 'OUT_OF_RADIUS',
            ])
            ->assertJsonStructure(['data' => ['distance_meter']]);

        $this->assertGreaterThan(1000, $response->json('data.distance_meter'));
        $this->assertSame(0, Absensi::count());
        $this->assertEmpty(Storage::disk('private')->allFiles());
    }

    public function test_face_mismatch_returns_422_with_similarity_and_does_not_save_row(): void
    {
        // Vektor ortogonal terhadap basis 0 -> cosine similarity = 0.0 < threshold 0.75
        $wrongFacePayload = $this->validPayload([
            'embedding' => json_encode($this->makeBasisEmbedding(1)),
        ]);

        $response = $this->withHeader('Authorization', "Bearer {$this->token}")
            ->post('/api/v1/attendance/check-in', $wrongFacePayload, ['Accept' => 'application/json']);

        $response->assertStatus(422)
            ->assertJson([
                'success' => false,
                'code'    => 'FACE_MISMATCH',
                'data'    => [
                    'similarity' => 0,
                ],
            ]);

        $this->assertSame(0, Absensi::count());
        $this->assertEmpty(Storage::disk('private')->allFiles());
    }

    public function test_history_endpoint_filters_by_month_and_summarizes_all_statuses(): void
    {
        Absensi::create([
            'id_karyawan' => $this->karyawan->id_karyawan,
            'id_shift'    => $this->shiftReguler->id_shift,
            'id_lokasi'   => $this->lokasiPusat->id_lokasi,
            'tanggal'     => '2026-11-02',
            'jam_masuk'   => '07:55:00',
            'jam_pulang'  => '16:02:00',
            'skor_wajah'  => 0.9100,
            'status'      => Absensi::STATUS_HADIR,
        ]);
        Absensi::create([
            'id_karyawan' => $this->karyawan->id_karyawan,
            'id_shift'    => $this->shiftReguler->id_shift,
            'id_lokasi'   => $this->lokasiPusat->id_lokasi,
            'tanggal'     => '2026-11-03',
            'jam_masuk'   => '08:20:00',
            'jam_pulang'  => '16:05:00',
            'skor_wajah'  => 0.8800,
            'status'      => Absensi::STATUS_TERLAMBAT,
        ]);
        Absensi::create([
            'id_karyawan' => $this->karyawan->id_karyawan,
            'tanggal'     => '2026-11-30',
            'status'      => Absensi::STATUS_CUTI,
            'keterangan'  => 'Cuti tahunan',
        ]);
        // Bulan berbeda (Oktober) tidak boleh masuk ke rekap November
        Absensi::create([
            'id_karyawan' => $this->karyawan->id_karyawan,
            'tanggal'     => '2026-10-31',
            'status'      => Absensi::STATUS_ALPA,
        ]);

        $response = $this->withHeader('Authorization', "Bearer {$this->token}")
            ->getJson('/api/v1/attendance/history?month=2026-11');

        $response->assertStatus(200)
            ->assertJson([
                'success' => true,
                'data'    => [
                    'month'   => '2026-11',
                    'summary' => [
                        'hadir'     => 1,
                        'terlambat' => 1,
                        'izin'      => 0,
                        'sakit'     => 0,
                        'cuti'      => 1,
                        'alpa'      => 0,
                    ],
                ],
            ])
            ->assertJsonCount(3, 'data.items');

        // Validasi format month tidak valid -> 422 VALIDATION_ERROR
        $this->withHeader('Authorization', "Bearer {$this->token}")
            ->getJson('/api/v1/attendance/history?month=2026-13')
            ->assertStatus(422)
            ->assertJson(['success' => false, 'code' => 'VALIDATION_ERROR']);
    }
}
