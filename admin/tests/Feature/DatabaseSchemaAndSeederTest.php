<?php

namespace Tests\Feature;

use Tests\TestCase;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Schema;
use Illuminate\Support\Facades\Hash;
use App\Models\Departemen;
use App\Models\Jabatan;
use App\Models\Karyawan;
use App\Models\Pengguna;
use App\Models\Shift;
use App\Models\LokasiKantor;
use App\Models\JadwalKaryawan;
use App\Models\HariLibur;
use App\Models\Absensi;
use App\Models\PengajuanIzin;
use App\Models\DataWajah;

class DatabaseSchemaAndSeederTest extends TestCase
{
    use RefreshDatabase;

    public function test_all_11_siakar_tables_exist(): void
    {
        $tables = [
            'departemen',
            'jabatan',
            'karyawan',
            'pengguna',
            'data_wajah',
            'shift',
            'jadwal_karyawan',
            'lokasi_kantor',
            'absensi',
            'pengajuan_izin',
            'hari_libur',
        ];

        foreach ($tables as $table) {
            $this->assertTrue(Schema::hasTable($table), "Table '$table' does not exist.");
        }
    }

    public function test_database_seeder_populates_demo_data(): void
    {
        $this->seed();

        $this->assertGreaterThanOrEqual(3, Departemen::count());
        $this->assertGreaterThanOrEqual(3, Jabatan::count());
        $this->assertGreaterThanOrEqual(4, Karyawan::count());
        $this->assertGreaterThanOrEqual(4, Pengguna::count());
        $this->assertGreaterThanOrEqual(2, Shift::count());
        $this->assertGreaterThanOrEqual(2, LokasiKantor::count());
        $this->assertGreaterThanOrEqual(1, HariLibur::count());

        // Verify Admin user
        $adminPengguna = Pengguna::where('username', 'admin')->first();
        $this->assertNotNull($adminPengguna);
        $this->assertEquals(Pengguna::ROLE_ADMIN, $adminPengguna->role);
        $this->assertTrue(Hash::check('password123', $adminPengguna->password_hash));
        $this->assertNotNull($adminPengguna->karyawan);

        // Verify Atasan user and subordinate hierarchy
        $atasanPengguna = Pengguna::where('username', 'atasan')->first();
        $this->assertNotNull($atasanPengguna);
        $this->assertEquals(Pengguna::ROLE_ATASAN, $atasanPengguna->role);

        $karyawan1 = Karyawan::where('nik', 'KRY-001')->first();
        $this->assertNotNull($karyawan1);
        $this->assertEquals($atasanPengguna->id_karyawan, $karyawan1->id_atasan);

        // Verify Models timestamps false
        $this->assertFalse((new Karyawan())->timestamps);
        $this->assertFalse((new Pengguna())->timestamps);
        $this->assertFalse((new Absensi())->timestamps);
        $this->assertFalse((new PengajuanIzin())->timestamps);
        $this->assertFalse((new DataWajah())->timestamps);
    }
}
