<?php

namespace Tests\Feature;

use App\Models\DataWajah;
use App\Models\Departemen;
use App\Models\Jabatan;
use App\Models\Karyawan;
use App\Models\Pengguna;
use Carbon\Carbon;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Storage;
use Tests\TestCase;

class AdminMasterCrudTest extends TestCase
{
    use RefreshDatabase;

    private Pengguna $adminUser;
    private Pengguna $karyawanUser;
    private Departemen $dept;
    private Jabatan $jab;
    private Karyawan $karyawan;

    protected function setUp(): void
    {
        parent::setUp();

        Storage::fake('private');

        $this->dept = Departemen::create(['nama_departemen' => 'Teknologi Informasi']);
        $this->jab = Jabatan::create(['nama_jabatan' => 'Developer']);

        $this->karyawan = Karyawan::create([
            'nik'           => 'KRY-501',
            'nama'          => 'Dewi Lestari',
            'jenis_kelamin' => 'P',
            'tanggal_lahir' => '1996-05-05',
            'tanggal_masuk' => '2022-01-10',
            'id_departemen' => $this->dept->id_departemen,
            'id_jabatan'    => $this->jab->id_jabatan,
            'status_aktif'  => true,
        ]);

        $this->karyawanUser = Pengguna::create([
            'id_karyawan'   => $this->karyawan->id_karyawan,
            'username'      => 'dewi_staff',
            'password_hash' => Hash::make('secret123'),
            'role'          => Pengguna::ROLE_KARYAWAN,
            'device_id'     => 'device-dewi-01',
        ]);

        $this->adminUser = Pengguna::create([
            'id_karyawan'   => null,
            'username'      => 'admin_panel',
            'password_hash' => Hash::make('secret123'),
            'role'          => Pengguna::ROLE_ADMIN,
        ]);
    }

    public function test_admin_routes_require_admin_role_and_reject_non_admin(): void
    {
        // Guest diarahkan ke login admin
        $this->get('/admin')->assertRedirect(route('admin.login'));

        // Non-admin (karyawan) ditolak saat login web admin
        $this->post('/admin/login', [
            'username' => 'dewi_staff',
            'password' => 'secret123',
        ])->assertSessionHasErrors('username');

        // Non-admin yang sudah terautentikasi ditolak 403 di /admin
        $this->actingAs($this->karyawanUser)
            ->get('/admin')
            ->assertStatus(403);

        // Admin dapat login dan mengakses dasbor
        $this->post('/admin/login', [
            'username' => 'admin_panel',
            'password' => 'secret123',
        ])->assertRedirect(route('admin.dashboard'));

        $this->actingAs($this->adminUser)
            ->get('/admin')
            ->assertStatus(200)
            ->assertSee('Selamat Datang di Panel Admin SIAKAR');
    }

    public function test_departemen_and_jabatan_crud_work(): void
    {
        $this->actingAs($this->adminUser);

        // Departemen: tambah, ubah, hapus
        $this->post('/admin/departemen', ['nama_departemen' => 'Keuangan'])
            ->assertRedirect(route('admin.departemen.index'));
        $this->assertDatabaseHas('departemen', ['nama_departemen' => 'Keuangan']);

        $keuangan = Departemen::where('nama_departemen', 'Keuangan')->firstOrFail();
        $this->put("/admin/departemen/{$keuangan->id_departemen}", ['nama_departemen' => 'Keuangan & Pajak'])
            ->assertRedirect(route('admin.departemen.index'));
        $this->assertDatabaseHas('departemen', ['nama_departemen' => 'Keuangan & Pajak']);

        $this->delete("/admin/departemen/{$keuangan->id_departemen}")
            ->assertRedirect(route('admin.departemen.index'));
        $this->assertDatabaseMissing('departemen', ['id_departemen' => $keuangan->id_departemen]);

        // Jabatan: tambah, ubah, hapus
        $this->post('/admin/jabatan', ['nama_jabatan' => 'QA Engineer'])
            ->assertRedirect(route('admin.jabatan.index'));
        $this->assertDatabaseHas('jabatan', ['nama_jabatan' => 'QA Engineer']);

        $qa = Jabatan::where('nama_jabatan', 'QA Engineer')->firstOrFail();
        $this->put("/admin/jabatan/{$qa->id_jabatan}", ['nama_jabatan' => 'Senior QA'])
            ->assertRedirect(route('admin.jabatan.index'));
        $this->assertDatabaseHas('jabatan', ['nama_jabatan' => 'Senior QA']);

        $this->delete("/admin/jabatan/{$qa->id_jabatan}")
            ->assertRedirect(route('admin.jabatan.index'));
        $this->assertDatabaseMissing('jabatan', ['id_jabatan' => $qa->id_jabatan]);
    }

    public function test_karyawan_crud_deactivate_and_reset_face_and_device(): void
    {
        $this->actingAs($this->adminUser);

        // Tambah karyawan + akun pengguna
        $this->post('/admin/karyawan', [
            'nik'           => 'KRY-502',
            'nama'          => 'Bambang Wijaya',
            'jenis_kelamin' => 'L',
            'tanggal_lahir' => '1994-07-17',
            'tanggal_masuk' => '2024-01-02',
            'id_departemen' => $this->dept->id_departemen,
            'id_jabatan'    => $this->jab->id_jabatan,
            'id_atasan'     => $this->karyawan->id_karyawan,
            'username'      => 'bambang_w',
            'password'      => 'secret123',
            'role'          => Pengguna::ROLE_KARYAWAN,
        ])->assertRedirect(route('admin.karyawan.index'));

        $this->assertDatabaseHas('karyawan', [
            'nik'          => 'KRY-502',
            'nama'         => 'Bambang Wijaya',
            'id_atasan'    => $this->karyawan->id_karyawan,
            'status_aktif' => 1,
        ]);
        $this->assertDatabaseHas('pengguna', [
            'username' => 'bambang_w',
            'role'     => 'karyawan',
        ]);

        // Pencarian karyawan
        $this->get('/admin/karyawan?search=Bambang')
            ->assertStatus(200)
            ->assertSee('Bambang Wijaya')
            ->assertDontSee('KRY-501');

        // Nonaktifkan karyawan (bukan hapus)
        $bambang = Karyawan::where('nik', 'KRY-502')->firstOrFail();
        $this->post("/admin/karyawan/{$bambang->id_karyawan}/deactivate")
            ->assertRedirect(route('admin.karyawan.index'));
        $this->assertDatabaseHas('karyawan', [
            'id_karyawan'  => $bambang->id_karyawan,
            'status_aktif' => 0,
        ]);

        // Reset wajah & reset perangkat pada karyawan
        Storage::disk('private')->put('faces/501/ref.png', 'dummy');
        DataWajah::create([
            'id_karyawan'    => $this->karyawan->id_karyawan,
            'embedding'      => 'encrypted-embedding',
            'foto_referensi' => 'faces/501/ref.png',
            'tanggal_daftar' => Carbon::now('Asia/Jakarta'),
            'aktif'          => true,
        ]);

        $this->post("/admin/karyawan/{$this->karyawan->id_karyawan}/reset-face")
            ->assertRedirect(route('admin.karyawan.index'));
        $this->assertDatabaseMissing('data_wajah', ['id_karyawan' => $this->karyawan->id_karyawan]);
        Storage::disk('private')->assertMissing('faces/501/ref.png');

        $this->post("/admin/karyawan/{$this->karyawan->id_karyawan}/reset-device")
            ->assertRedirect(route('admin.karyawan.index'));
        $this->assertDatabaseHas('pengguna', [
            'id_karyawan' => $this->karyawan->id_karyawan,
            'device_id'   => null,
        ]);
    }
}
