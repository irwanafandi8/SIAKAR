<?php

namespace Database\Seeders;

use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\DB;
use App\Models\Departemen;
use App\Models\Jabatan;
use App\Models\Karyawan;
use App\Models\Pengguna;
use App\Models\Shift;
use App\Models\LokasiKantor;
use App\Models\JadwalKaryawan;
use App\Models\HariLibur;
use Carbon\Carbon;

class DatabaseSeeder extends Seeder
{
    public function run(): void
    {
        // 1. Departemen
        $deptTI = Departemen::create(['nama_departemen' => 'Teknologi Informasi']);
        $deptSDM = Departemen::create(['nama_departemen' => 'Sumber Daya Manusia']);
        $deptOps = Departemen::create(['nama_departemen' => 'Operasional']);

        // 2. Jabatan
        $jabManager = Jabatan::create(['nama_jabatan' => 'Manager']);
        $jabStaffSenior = Jabatan::create(['nama_jabatan' => 'Staff Senior']);
        $jabStaffJunior = Jabatan::create(['nama_jabatan' => 'Staff Junior']);

        // 3. Karyawan
        // Admin
        $karAdmin = Karyawan::create([
            'nik'           => 'ADM-001',
            'nama'          => 'Budi Santoso',
            'jenis_kelamin' => 'L',
            'tanggal_lahir' => '1985-05-12',
            'email'         => 'admin@siakar.local',
            'no_hp'         => '081234567890',
            'alamat'        => 'Jl. Merdeka No. 1, Indramayu',
            'tanggal_masuk' => '2020-01-01',
            'id_departemen' => $deptSDM->id_departemen,
            'id_jabatan'    => $jabManager->id_jabatan,
            'id_atasan'     => null,
            'status_aktif'  => true,
        ]);

        // Atasan
        $karAtasan = Karyawan::create([
            'nik'           => 'ATS-001',
            'nama'          => 'Ahmad Fauzi',
            'jenis_kelamin' => 'L',
            'tanggal_lahir' => '1988-08-20',
            'email'         => 'fauzi@siakar.local',
            'no_hp'         => '081234567891',
            'alamat'        => 'Jl. Pahlawan No. 45, Indramayu',
            'tanggal_masuk' => '2021-03-01',
            'id_departemen' => $deptTI->id_departemen,
            'id_jabatan'    => $jabManager->id_jabatan,
            'id_atasan'     => $karAdmin->id_karyawan,
            'status_aktif'  => true,
        ]);

        // Karyawan 1
        $karKaryawan1 = Karyawan::create([
            'nik'           => 'KRY-001',
            'nama'          => 'Siti Rahmawati',
            'jenis_kelamin' => 'P',
            'tanggal_lahir' => '1995-11-15',
            'email'         => 'siti@siakar.local',
            'no_hp'         => '081234567892',
            'alamat'        => 'Jl. Sudirman No. 10, Indramayu',
            'tanggal_masuk' => '2022-07-01',
            'id_departemen' => $deptTI->id_departemen,
            'id_jabatan'    => $jabStaffSenior->id_jabatan,
            'id_atasan'     => $karAtasan->id_karyawan,
            'status_aktif'  => true,
        ]);

        // Karyawan 2
        $karKaryawan2 = Karyawan::create([
            'nik'           => 'KRY-002',
            'nama'          => 'Rizky Pratama',
            'jenis_kelamin' => 'L',
            'tanggal_lahir' => '1998-03-25',
            'email'         => 'rizky@siakar.local',
            'no_hp'         => '081234567893',
            'alamat'        => 'Jl. Kartini No. 22, Indramayu',
            'tanggal_masuk' => '2023-02-01',
            'id_departemen' => $deptTI->id_departemen,
            'id_jabatan'    => $jabStaffJunior->id_jabatan,
            'id_atasan'     => $karAtasan->id_karyawan,
            'status_aktif'  => true,
        ]);

        // 4. Pengguna (Akun login)
        Pengguna::create([
            'id_karyawan'   => $karAdmin->id_karyawan,
            'username'      => 'admin',
            'password_hash' => Hash::make('password123'),
            'role'          => Pengguna::ROLE_ADMIN,
            'device_id'     => null,
        ]);

        Pengguna::create([
            'id_karyawan'   => $karAtasan->id_karyawan,
            'username'      => 'atasan',
            'password_hash' => Hash::make('password123'),
            'role'          => Pengguna::ROLE_ATASAN,
            'device_id'     => null,
        ]);

        Pengguna::create([
            'id_karyawan'   => $karKaryawan1->id_karyawan,
            'username'      => 'karyawan1',
            'password_hash' => Hash::make('password123'),
            'role'          => Pengguna::ROLE_KARYAWAN,
            'device_id'     => null,
        ]);

        Pengguna::create([
            'id_karyawan'   => $karKaryawan2->id_karyawan,
            'username'      => 'karyawan2',
            'password_hash' => Hash::make('password123'),
            'role'          => Pengguna::ROLE_KARYAWAN,
            'device_id'     => null,
        ]);

        // 5. Shift
        $shiftReguler = Shift::create([
            'nama_shift'      => 'Reguler',
            'jam_masuk'       => '08:00:00',
            'jam_pulang'      => '16:00:00',
            'toleransi_menit' => 10,
        ]);

        $shiftPagi = Shift::create([
            'nama_shift'      => 'Shift Pagi',
            'jam_masuk'       => '07:00:00',
            'jam_pulang'      => '15:00:00',
            'toleransi_menit' => 15,
        ]);

        // 6. Lokasi Kantor
        $lokasiPusat = LokasiKantor::create([
            'nama_lokasi'  => 'Kantor Pusat',
            'latitude'     => -6.32770000,
            'longitude'    => 108.32000000,
            'radius_meter' => 100,
        ]);

        LokasiKantor::create([
            'nama_lokasi'  => 'Kantor Cabang',
            'latitude'     => -6.33000000,
            'longitude'    => 108.32500000,
            'radius_meter' => 150,
        ]);

        // 7. Hari Libur
        HariLibur::create([
            'tanggal'    => '2026-12-25',
            'keterangan' => 'Hari Raya Natal',
        ]);
        HariLibur::create([
            'tanggal'    => '2026-01-01',
            'keterangan' => 'Tahun Baru Masehi',
        ]);
        HariLibur::create([
            'tanggal'    => '2026-08-17',
            'keterangan' => 'Hari Kemerdekaan RI',
        ]);

        // 8. Jadwal Karyawan (untuk rentang 30 hari ke belakang dan ke depan)
        $karyawanList = [$karAtasan, $karKaryawan1, $karKaryawan2];
        $startDate = Carbon::today()->subDays(15);
        $endDate = Carbon::today()->addDays(15);

        for ($date = $startDate->copy(); $date->lte($endDate); $date->addDay()) {
            // Lewati hari Minggu (dayOfWeek == 0)
            if ($date->dayOfWeek === Carbon::SUNDAY) {
                continue;
            }

            foreach ($karyawanList as $karyawan) {
                JadwalKaryawan::create([
                    'id_karyawan' => $karyawan->id_karyawan,
                    'id_shift'    => $shiftReguler->id_shift,
                    'tanggal'     => $date->toDateString(),
                ]);
            }
        }
    }
}
