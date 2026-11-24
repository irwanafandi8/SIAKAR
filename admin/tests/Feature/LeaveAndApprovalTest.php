<?php

namespace Tests\Feature;

use App\Models\Absensi;
use App\Models\Departemen;
use App\Models\Jabatan;
use App\Models\Karyawan;
use App\Models\PengajuanIzin;
use App\Models\Pengguna;
use App\Services\LeaveService;
use Carbon\Carbon;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Storage;
use RuntimeException;
use Tests\TestCase;

class LeaveAndApprovalTest extends TestCase
{
    use RefreshDatabase;

    private Karyawan $atasan;
    private Karyawan $atasanLain;
    private Karyawan $karyawan;
    private Pengguna $karyawanUser;
    private Pengguna $atasanUser;
    private Pengguna $atasanLainUser;
    private Pengguna $adminUser;
    private string $karyawanToken;
    private string $atasanToken;
    private string $atasanLainToken;
    private string $adminToken;

    protected function setUp(): void
    {
        parent::setUp();

        Storage::fake('private');
        Storage::fake('public');
        Carbon::setTestNow(Carbon::create(2026, 11, 24, 9, 0, 0, 'Asia/Jakarta'));

        $dept = Departemen::create(['nama_departemen' => 'Teknologi Informasi']);
        $jabMgr = Jabatan::create(['nama_jabatan' => 'Manager']);
        $jabStaff = Jabatan::create(['nama_jabatan' => 'Staff']);

        $this->atasan = Karyawan::create([
            'nik'           => 'ATS-201',
            'nama'          => 'Atasan Langsung',
            'jenis_kelamin' => 'L',
            'tanggal_lahir' => '1988-01-01',
            'tanggal_masuk' => '2020-01-01',
            'id_departemen' => $dept->id_departemen,
            'id_jabatan'    => $jabMgr->id_jabatan,
            'status_aktif'  => true,
        ]);

        $this->atasanLain = Karyawan::create([
            'nik'           => 'ATS-202',
            'nama'          => 'Atasan Lain',
            'jenis_kelamin' => 'L',
            'tanggal_lahir' => '1987-02-02',
            'tanggal_masuk' => '2020-01-01',
            'id_departemen' => $dept->id_departemen,
            'id_jabatan'    => $jabMgr->id_jabatan,
            'status_aktif'  => true,
        ]);

        $this->karyawan = Karyawan::create([
            'nik'           => 'KRY-201',
            'nama'          => 'Pemohon Izin',
            'jenis_kelamin' => 'P',
            'tanggal_lahir' => '1997-03-03',
            'tanggal_masuk' => '2023-01-01',
            'id_departemen' => $dept->id_departemen,
            'id_jabatan'    => $jabStaff->id_jabatan,
            'id_atasan'     => $this->atasan->id_karyawan,
            'status_aktif'  => true,
        ]);

        $this->karyawanUser = Pengguna::create([
            'id_karyawan'   => $this->karyawan->id_karyawan,
            'username'      => 'pemohon_izin',
            'password_hash' => Hash::make('secret123'),
            'role'          => Pengguna::ROLE_KARYAWAN,
        ]);

        $this->atasanUser = Pengguna::create([
            'id_karyawan'   => $this->atasan->id_karyawan,
            'username'      => 'atasan_langsung',
            'password_hash' => Hash::make('secret123'),
            'role'          => Pengguna::ROLE_ATASAN,
        ]);

        $this->atasanLainUser = Pengguna::create([
            'id_karyawan'   => $this->atasanLain->id_karyawan,
            'username'      => 'atasan_lain',
            'password_hash' => Hash::make('secret123'),
            'role'          => Pengguna::ROLE_ATASAN,
        ]);

        $this->adminUser = Pengguna::create([
            'id_karyawan'   => null,
            'username'      => 'admin_izin',
            'password_hash' => Hash::make('secret123'),
            'role'          => Pengguna::ROLE_ADMIN,
        ]);

        $this->karyawanToken = $this->karyawanUser->createToken('k-token')->plainTextToken;
        $this->atasanToken = $this->atasanUser->createToken('a-token')->plainTextToken;
        $this->atasanLainToken = $this->atasanLainUser->createToken('al-token')->plainTextToken;
        $this->adminToken = $this->adminUser->createToken('adm-token')->plainTextToken;
    }

    protected function tearDown(): void
    {
        Carbon::setTestNow();
        parent::tearDown();
    }

    public function test_role_authorization_for_leaves_approvals_and_recap(): void
    {
        // Tanpa token -> 401
        $this->getJson('/api/v1/leaves')->assertStatus(401)->assertJson(['code' => 'UNAUTHENTICATED']);
        $this->getJson('/api/v1/approvals')->assertStatus(401)->assertJson(['code' => 'UNAUTHENTICATED']);

        // Admin ditolak di endpoint mobile -> 403 FORBIDDEN_ROLE
        $this->withHeader('Authorization', "Bearer {$this->adminToken}")
            ->getJson('/api/v1/leaves')
            ->assertStatus(403)
            ->assertJson(['code' => 'FORBIDDEN_ROLE']);

        $this->withHeader('Authorization', "Bearer {$this->adminToken}")
            ->getJson('/api/v1/approvals')
            ->assertStatus(403)
            ->assertJson(['code' => 'FORBIDDEN_ROLE']);

        // Karyawan ditolak di endpoint atasan (/approvals & /team/recap) -> 403 FORBIDDEN_ROLE
        $this->withHeader('Authorization', "Bearer {$this->karyawanToken}")
            ->getJson('/api/v1/approvals')
            ->assertStatus(403)
            ->assertJson(['code' => 'FORBIDDEN_ROLE']);

        $this->withHeader('Authorization', "Bearer {$this->karyawanToken}")
            ->getJson('/api/v1/team/recap?from=2026-11-01&to=2026-11-30')
            ->assertStatus(403)
            ->assertJson(['code' => 'FORBIDDEN_ROLE']);
    }

    public function test_karyawan_can_submit_and_list_leave_with_private_attachment_and_overlap_check(): void
    {
        $pdf = UploadedFile::fake()->create('surat_dokter.pdf', 100, 'application/pdf');

        $createRes = $this->withHeader('Authorization', "Bearer {$this->karyawanToken}")
            ->post('/api/v1/leaves', [
                'jenis'           => 'sakit',
                'tanggal_mulai'   => '2026-11-25',
                'tanggal_selesai' => '2026-11-26',
                'alasan'          => 'Demam tinggi',
                'lampiran'        => $pdf,
            ], ['Accept' => 'application/json']);

        $createRes->assertStatus(201)
            ->assertJson([
                'success' => true,
                'data'    => [
                    'jenis'           => 'sakit',
                    'tanggal_mulai'   => '2026-11-25',
                    'tanggal_selesai' => '2026-11-26',
                    'status'          => 'menunggu',
                    'pemohon'         => [
                        'id_karyawan' => $this->karyawan->id_karyawan,
                        'nama'        => 'Pemohon Izin',
                    ],
                ],
            ]);

        $izin = PengajuanIzin::firstOrFail();
        $this->assertNotNull($izin->lampiran);
        Storage::disk('private')->assertExists($izin->lampiran);
        $this->assertEmpty(Storage::disk('public')->allFiles());

        // Tumpang tindih dengan pengajuan menunggu -> 422 VALIDATION_ERROR
        $this->withHeader('Authorization', "Bearer {$this->karyawanToken}")
            ->post('/api/v1/leaves', [
                'jenis'           => 'izin',
                'tanggal_mulai'   => '2026-11-26',
                'tanggal_selesai' => '2026-11-27',
                'alasan'          => 'Urusan keluarga',
            ], ['Accept' => 'application/json'])
            ->assertStatus(422)
            ->assertJson(['success' => false, 'code' => 'VALIDATION_ERROR']);

        // Daftar pengajuan milik sendiri
        $this->withHeader('Authorization', "Bearer {$this->karyawanToken}")
            ->getJson('/api/v1/leaves?status=menunggu')
            ->assertStatus(200)
            ->assertJsonCount(1, 'data');
    }

    public function test_direct_supervisor_can_approve_and_records_attendance_for_date_range(): void
    {
        $izin = PengajuanIzin::create([
            'id_karyawan'       => $this->karyawan->id_karyawan,
            'jenis'             => PengajuanIzin::JENIS_CUTI,
            'tanggal_mulai'     => '2026-11-25',
            'tanggal_selesai'   => '2026-11-27',
            'alasan'            => 'Cuti keluarga',
            'status'            => PengajuanIzin::STATUS_MENUNGGU,
            'tanggal_pengajuan' => Carbon::now('Asia/Jakarta'),
        ]);

        // Daftar menunggu untuk atasan langsung
        $this->withHeader('Authorization', "Bearer {$this->atasanToken}")
            ->getJson('/api/v1/approvals?status=menunggu')
            ->assertStatus(200)
            ->assertJsonCount(1, 'data');

        // Setujui
        $approveRes = $this->withHeader('Authorization', "Bearer {$this->atasanToken}")
            ->postJson("/api/v1/approvals/{$izin->id_izin}/approve");

        $approveRes->assertStatus(200)
            ->assertJson([
                'success' => true,
                'data'    => [
                    'id_izin' => $izin->id_izin,
                    'status'  => 'disetujui',
                ],
            ]);

        $this->assertDatabaseHas('pengajuan_izin', [
            'id_izin'      => $izin->id_izin,
            'status'       => 'disetujui',
            'id_penyetuju' => $this->atasan->id_karyawan,
        ]);

        // Pastikan 3 tanggal (25, 26, 27) tercatat di tabel absensi dengan status 'cuti'
        foreach (['2026-11-25', '2026-11-26', '2026-11-27'] as $tanggal) {
            $row = Absensi::where('id_karyawan', $this->karyawan->id_karyawan)
                ->whereDate('tanggal', $tanggal)
                ->first();
            $this->assertNotNull($row);
            $this->assertSame('cuti', $row->status);
        }
    }

    public function test_direct_supervisor_can_reject_and_non_approver_gets_403(): void
    {
        $izin = PengajuanIzin::create([
            'id_karyawan'       => $this->karyawan->id_karyawan,
            'jenis'             => PengajuanIzin::JENIS_IZIN,
            'tanggal_mulai'     => '2026-11-28',
            'tanggal_selesai'   => '2026-11-28',
            'alasan'            => 'Keperluan pribadi',
            'status'            => PengajuanIzin::STATUS_MENUNGGU,
            'tanggal_pengajuan' => Carbon::now('Asia/Jakarta'),
        ]);

        // Bukan atasan langsung -> 403 NOT_APPROVER
        $this->withHeader('Authorization', "Bearer {$this->atasanLainToken}")
            ->postJson("/api/v1/approvals/{$izin->id_izin}/approve")
            ->assertStatus(403)
            ->assertJson(['success' => false, 'code' => 'NOT_APPROVER']);

        $this->withHeader('Authorization', "Bearer {$this->atasanLainToken}")
            ->postJson("/api/v1/approvals/{$izin->id_izin}/reject")
            ->assertStatus(403)
            ->assertJson(['success' => false, 'code' => 'NOT_APPROVER']);

        // Atasan langsung menolak -> 200 ditolak, tidak ada baris absensi
        $this->app['auth']->forgetGuards();
        $this->withHeader('Authorization', "Bearer {$this->atasanToken}")
            ->postJson("/api/v1/approvals/{$izin->id_izin}/reject")
            ->assertStatus(200)
            ->assertJson([
                'success' => true,
                'data'    => ['status' => 'ditolak'],
            ]);

        $this->assertSame(0, Absensi::count());
    }

    public function test_approve_rolls_back_transaction_if_mid_operation_fails(): void
    {
        $izin = PengajuanIzin::create([
            'id_karyawan'       => $this->karyawan->id_karyawan,
            'jenis'             => PengajuanIzin::JENIS_IZIN,
            'tanggal_mulai'     => '2026-11-25',
            'tanggal_selesai'   => '2026-11-26',
            'alasan'            => 'Uji rollback',
            'status'            => PengajuanIzin::STATUS_MENUNGGU,
            'tanggal_pengajuan' => Carbon::now('Asia/Jakarta'),
        ]);

        // Simulasikan kegagalan saat menyimpan baris absensi kedua di dalam transaksi
        $count = 0;
        Absensi::creating(function () use (&$count): void {
            $count++;
            if ($count === 2) {
                throw new RuntimeException('Simulasi kegagalan DB di tengah transaksi');
            }
        });

        try {
            app(LeaveService::class)->approve($this->atasan, $izin->id_izin);
            $this->fail('Seharusnya melempar RuntimeException');
        } catch (RuntimeException $e) {
            $this->assertSame('Simulasi kegagalan DB di tengah transaksi', $e->getMessage());
        } finally {
            Absensi::flushEventListeners();
        }

        // Status pengajuan tetap 'menunggu' dan tidak ada baris absensi yang tersimpan
        $this->assertDatabaseHas('pengajuan_izin', [
            'id_izin'      => $izin->id_izin,
            'status'       => 'menunggu',
            'id_penyetuju' => null,
        ]);
        $this->assertSame(0, Absensi::count());
    }

    public function test_team_recap_returns_subordinates_attendance_summary(): void
    {
        Absensi::create([
            'id_karyawan' => $this->karyawan->id_karyawan,
            'tanggal'     => '2026-11-20',
            'status'      => Absensi::STATUS_HADIR,
        ]);
        Absensi::create([
            'id_karyawan' => $this->karyawan->id_karyawan,
            'tanggal'     => '2026-11-21',
            'status'      => Absensi::STATUS_TERLAMBAT,
        ]);

        $this->withHeader('Authorization', "Bearer {$this->atasanToken}")
            ->getJson('/api/v1/team/recap?from=2026-11-01&to=2026-11-30')
            ->assertStatus(200)
            ->assertJson([
                'success' => true,
                'data'    => [
                    'items' => [
                        [
                            'id_karyawan' => $this->karyawan->id_karyawan,
                            'nama'        => 'Pemohon Izin',
                            'hadir'       => 1,
                            'terlambat'   => 1,
                            'izin'        => 0,
                            'sakit'       => 0,
                            'cuti'        => 0,
                            'alpa'        => 0,
                        ],
                    ],
                ],
            ]);
    }
}
