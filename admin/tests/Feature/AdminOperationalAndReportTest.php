<?php

namespace Tests\Feature;

use App\Models\Absensi;
use App\Models\Departemen;
use App\Models\HariLibur;
use App\Models\Jabatan;
use App\Models\JadwalKaryawan;
use App\Models\Karyawan;
use App\Models\LokasiKantor;
use App\Models\Pengguna;
use App\Models\Shift;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Tests\TestCase;

class AdminOperationalAndReportTest extends TestCase
{
    use RefreshDatabase;

    private Pengguna $adminUser;
    private Karyawan $karyawan;
    private Shift $shift;

    protected function setUp(): void
    {
        parent::setUp();

        $dept = Departemen::create(['nama_departemen' => 'Operasional']);
        $jab = Jabatan::create(['nama_jabatan' => 'Staff']);

        $this->karyawan = Karyawan::create([
            'nik'           => 'KRY-701',
            'nama'          => 'Andi Saputra',
            'jenis_kelamin' => 'L',
            'tanggal_lahir' => '1995-01-01',
            'tanggal_masuk' => '2022-01-01',
            'id_departemen' => $dept->id_departemen,
            'id_jabatan'    => $jab->id_jabatan,
            'status_aktif'  => true,
        ]);

        $this->adminUser = Pengguna::create([
            'id_karyawan'   => null,
            'username'      => 'admin_ops',
            'password_hash' => Hash::make('secret123'),
            'role'          => Pengguna::ROLE_ADMIN,
        ]);

        $this->shift = Shift::create([
            'nama_shift'      => 'Reguler',
            'jam_masuk'       => '08:00:00',
            'jam_pulang'      => '16:00:00',
            'toleransi_menit' => 10,
        ]);
    }

    public function test_shift_jadwal_lokasi_and_hari_libur_crud(): void
    {
        $this->actingAs($this->adminUser);

        // Shift
        $this->post('/admin/shift', [
            'nama_shift'      => 'Shift Siang',
            'jam_masuk'       => '13:00:00',
            'jam_pulang'      => '21:00:00',
            'toleransi_menit' => 15,
        ])->assertRedirect(route('admin.shift.index'));
        $this->assertDatabaseHas('shift', ['nama_shift' => 'Shift Siang']);

        // Jadwal
        $this->post('/admin/jadwal', [
            'id_karyawan' => $this->karyawan->id_karyawan,
            'id_shift'    => $this->shift->id_shift,
            'tanggal'     => '2026-11-24',
        ])->assertRedirect(route('admin.jadwal.index'));
        $this->assertTrue(
            JadwalKaryawan::where('id_karyawan', $this->karyawan->id_karyawan)
                ->whereDate('tanggal', '2026-11-24')
                ->exists()
        );

        // Lokasi
        $this->post('/admin/lokasi', [
            'nama_lokasi'  => 'Kantor Selatan',
            'latitude'     => -6.34000000,
            'longitude'    => 108.33000000,
            'radius_meter' => 120,
        ])->assertRedirect(route('admin.lokasi.index'));
        $this->assertDatabaseHas('lokasi_kantor', ['nama_lokasi' => 'Kantor Selatan', 'radius_meter' => 120]);

        // Hari Libur
        $this->post('/admin/hari-libur', [
            'tanggal'    => '2026-12-25',
            'keterangan' => 'Natal',
        ])->assertRedirect(route('admin.hari-libur.index'));
        $this->assertTrue(
            HariLibur::whereDate('tanggal', '2026-12-25')
                ->where('keterangan', 'Natal')
                ->exists()
        );
    }

    public function test_absensi_correction_requires_keterangan_and_updates_status(): void
    {
        $this->actingAs($this->adminUser);

        $absensi = Absensi::create([
            'id_karyawan' => $this->karyawan->id_karyawan,
            'tanggal'     => '2026-11-24',
            'status'      => Absensi::STATUS_ALPA,
        ]);

        // Tanpa keterangan -> ditolak validasi
        $this->put("/admin/absensi/{$absensi->id_absensi}", [
            'status'     => Absensi::STATUS_IZIN,
            'keterangan' => '',
        ])->assertSessionHasErrors('keterangan');

        // Dengan keterangan -> berhasil
        $this->put("/admin/absensi/{$absensi->id_absensi}", [
            'status'     => Absensi::STATUS_IZIN,
            'keterangan' => 'Koreksi surat izin manual',
        ])->assertRedirect(route('admin.absensi.index'));

        $this->assertDatabaseHas('absensi', [
            'id_absensi' => $absensi->id_absensi,
            'status'     => 'izin',
            'keterangan' => 'Koreksi surat izin manual',
        ]);
    }

    public function test_laporan_and_csv_export_contain_expected_headers_and_rows(): void
    {
        $this->actingAs($this->adminUser);

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

        $this->get('/admin/laporan?from=2026-11-01&to=2026-11-30')
            ->assertStatus(200)
            ->assertSee('Andi Saputra');

        $csvResponse = $this->get('/admin/laporan/export-csv?from=2026-11-01&to=2026-11-30');
        $csvResponse->assertStatus(200);
        $this->assertStringContainsString('text/csv', (string) $csvResponse->headers->get('Content-Type'));

        $csvContent = $csvResponse->streamedContent();
        $this->assertStringContainsString('NIK,Nama,Departemen,Hadir,Terlambat,Izin,Sakit,Cuti,Alpa', $csvContent);
        $this->assertStringContainsString('KRY-701,"Andi Saputra",Operasional,1,1,0,0,0,0', $csvContent);
    }
}
