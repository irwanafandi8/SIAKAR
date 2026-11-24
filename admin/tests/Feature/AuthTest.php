<?php

namespace Tests\Feature;

use Tests\TestCase;
use App\Models\Karyawan;
use App\Models\Pengguna;
use App\Models\Departemen;
use App\Models\Jabatan;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;

class AuthTest extends TestCase
{
    use RefreshDatabase;

    protected Pengguna $karyawanUser;
    protected Pengguna $adminUser;

    protected function setUp(): void
    {
        parent::setUp();

        $dept = Departemen::create(['nama_departemen' => 'TI']);
        $jab = Jabatan::create(['nama_jabatan' => 'Developer']);

        $karyawan = Karyawan::create([
            'nik'           => 'KRY-TEST-01',
            'nama'          => 'Budi Test',
            'jenis_kelamin' => 'L',
            'tanggal_lahir' => '1995-01-01',
            'tanggal_masuk' => '2023-01-01',
            'id_departemen' => $dept->id_departemen,
            'id_jabatan'    => $jab->id_jabatan,
        ]);

        $this->karyawanUser = Pengguna::create([
            'id_karyawan'   => $karyawan->id_karyawan,
            'username'      => 'karyawan_test',
            'password_hash' => Hash::make('secret123'),
            'role'          => Pengguna::ROLE_KARYAWAN,
            'device_id'     => null,
        ]);

        $this->adminUser = Pengguna::create([
            'username'      => 'admin_test',
            'password_hash' => Hash::make('secret123'),
            'role'          => Pengguna::ROLE_ADMIN,
        ]);
    }

    public function test_login_successful_and_binds_device(): void
    {
        $response = $this->postJson('/api/v1/auth/login', [
            'username'  => 'karyawan_test',
            'password'  => 'secret123',
            'device_id' => 'android_device_xyz_123',
        ]);

        $response->assertStatus(200)
            ->assertJson([
                'success' => true,
                'data'    => [
                    'user' => [
                        'username' => 'karyawan_test',
                        'role'     => 'karyawan',
                    ],
                ],
            ])
            ->assertJsonStructure([
                'data' => [
                    'token',
                    'user' => ['id_pengguna', 'id_karyawan', 'nama', 'nik', 'role', 'departemen', 'jabatan', 'face_enrolled'],
                ],
            ]);

        // Cek bahwa device_id terikat di basis data
        $this->assertDatabaseHas('pengguna', [
            'username'  => 'karyawan_test',
            'device_id' => 'android_device_xyz_123',
        ]);
    }

    public function test_login_fails_with_invalid_credentials(): void
    {
        $response = $this->postJson('/api/v1/auth/login', [
            'username'  => 'karyawan_test',
            'password'  => 'wrong_password',
            'device_id' => 'dev_1',
        ]);

        $response->assertStatus(401)
            ->assertJson([
                'success' => false,
                'code'    => 'INVALID_CREDENTIALS',
            ]);
    }

    public function test_login_fails_with_device_mismatch(): void
    {
        // Ikat perangkat pertama
        $this->karyawanUser->update(['device_id' => 'original_device_id']);

        // Coba login dari perangkat berbeda
        $response = $this->postJson('/api/v1/auth/login', [
            'username'  => 'karyawan_test',
            'password'  => 'secret123',
            'device_id' => 'different_device_id',
        ]);

        $response->assertStatus(403)
            ->assertJson([
                'success' => false,
                'code'    => 'DEVICE_MISMATCH',
            ]);
    }

    public function test_login_rejects_admin_role_on_mobile_api(): void
    {
        $response = $this->postJson('/api/v1/auth/login', [
            'username'  => 'admin_test',
            'password'  => 'secret123',
            'device_id' => 'admin_phone',
        ]);

        $response->assertStatus(403)
            ->assertJson([
                'success' => false,
                'code'    => 'FORBIDDEN_ROLE',
            ]);
    }

    public function test_login_validation_errors(): void
    {
        $response = $this->postJson('/api/v1/auth/login', []);

        $response->assertStatus(422)
            ->assertJson([
                'success' => false,
                'code'    => 'VALIDATION_ERROR',
            ])
            ->assertJsonStructure(['errors' => ['username', 'password', 'device_id']]);
    }

    public function test_me_endpoint_requires_auth(): void
    {
        $response = $this->getJson('/api/v1/me');
        $response->assertStatus(401)
            ->assertJson([
                'success' => false,
                'code'    => 'UNAUTHENTICATED',
            ]);
    }

    public function test_me_and_logout_endpoints_work_with_valid_token(): void
    {
        $token = $this->karyawanUser->createToken('test-token')->plainTextToken;

        // Test GET /api/v1/me
        $meResponse = $this->withHeader('Authorization', "Bearer $token")
            ->getJson('/api/v1/me');

        $meResponse->assertStatus(200)
            ->assertJson([
                'success' => true,
                'data'    => [
                    'username'   => 'karyawan_test',
                    'nama'       => 'Budi Test',
                    'role'       => 'karyawan',
                    'departemen' => 'TI',
                    'jabatan'    => 'Developer',
                ],
            ]);

        // Test POST /api/v1/auth/logout
        $logoutResponse = $this->withHeader('Authorization', "Bearer $token")
            ->postJson('/api/v1/auth/logout');

        $logoutResponse->assertStatus(200)
            ->assertJson([
                'success' => true,
                'message' => 'Berhasil logout',
            ]);

        // Verifikasi token telah dicabut
        $this->app['auth']->forgetGuards();
        $meAfterLogout = $this->withHeader('Authorization', "Bearer $token")
            ->getJson('/api/v1/me');
        $meAfterLogout->assertStatus(401);
    }
}
