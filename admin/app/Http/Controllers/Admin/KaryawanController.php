<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Http\Requests\Admin\KaryawanRequest;
use App\Models\DataWajah;
use App\Models\Departemen;
use App\Models\Jabatan;
use App\Models\Karyawan;
use App\Models\Pengguna;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Storage;
use Illuminate\View\View;

class KaryawanController extends Controller
{
    public function index(Request $request): View
    {
        $search = trim((string) $request->query('search', ''));

        $items = Karyawan::with(['departemen', 'jabatan', 'atasan', 'pengguna', 'dataWajah'])
            ->when($search !== '', function ($q) use ($search): void {
                $q->where(function ($sub) use ($search): void {
                    $sub->where('nama', 'like', "%{$search}%")
                        ->orWhere('nik', 'like', "%{$search}%");
                });
            })
            ->orderBy('nama')
            ->paginate(10)
            ->withQueryString();

        return view('admin.karyawan.index', compact('items', 'search'));
    }

    public function create(): View
    {
        return view('admin.karyawan.create', [
            'departemenList' => Departemen::orderBy('nama_departemen')->get(),
            'jabatanList'    => Jabatan::orderBy('nama_jabatan')->get(),
            'atasanList'     => Karyawan::where('status_aktif', true)->orderBy('nama')->get(),
        ]);
    }

    public function store(KaryawanRequest $request): RedirectResponse
    {
        $data = $request->validated();

        DB::transaction(function () use ($data, $request): void {
            $karyawan = Karyawan::create([
                'nik'           => $data['nik'],
                'nama'          => $data['nama'],
                'jenis_kelamin' => $data['jenis_kelamin'],
                'tanggal_lahir' => $data['tanggal_lahir'],
                'email'         => $data['email'] ?? null,
                'no_hp'         => $data['no_hp'] ?? null,
                'alamat'        => $data['alamat'] ?? null,
                'tanggal_masuk' => $data['tanggal_masuk'],
                'id_departemen' => $data['id_departemen'],
                'id_jabatan'    => $data['id_jabatan'],
                'id_atasan'     => $data['id_atasan'] ?? null,
                'status_aktif'  => $request->boolean('status_aktif', true),
            ]);

            Pengguna::create([
                'id_karyawan'   => $karyawan->id_karyawan,
                'username'      => $data['username'],
                'password_hash' => Hash::make((string) $data['password']),
                'role'          => $data['role'],
            ]);
        });

        return redirect()->route('admin.karyawan.index')->with('success', 'Karyawan berhasil ditambahkan.');
    }

    public function edit(Karyawan $karyawan): View
    {
        $karyawan->load(['pengguna', 'dataWajah']);

        return view('admin.karyawan.edit', [
            'karyawan'       => $karyawan,
            'departemenList' => Departemen::orderBy('nama_departemen')->get(),
            'jabatanList'    => Jabatan::orderBy('nama_jabatan')->get(),
            'atasanList'     => Karyawan::where('status_aktif', true)
                ->where('id_karyawan', '!=', $karyawan->id_karyawan)
                ->orderBy('nama')
                ->get(),
        ]);
    }

    public function update(KaryawanRequest $request, Karyawan $karyawan): RedirectResponse
    {
        $data = $request->validated();

        DB::transaction(function () use ($data, $request, $karyawan): void {
            $karyawan->update([
                'nik'           => $data['nik'],
                'nama'          => $data['nama'],
                'jenis_kelamin' => $data['jenis_kelamin'],
                'tanggal_lahir' => $data['tanggal_lahir'],
                'email'         => $data['email'] ?? null,
                'no_hp'         => $data['no_hp'] ?? null,
                'alamat'        => $data['alamat'] ?? null,
                'tanggal_masuk' => $data['tanggal_masuk'],
                'id_departemen' => $data['id_departemen'],
                'id_jabatan'    => $data['id_jabatan'],
                'id_atasan'     => $data['id_atasan'] ?? null,
                'status_aktif'  => $request->boolean('status_aktif', true),
            ]);

            $pengguna = $karyawan->pengguna;
            $userPayload = [
                'username' => $data['username'],
                'role'     => $data['role'],
            ];
            if (!empty($data['password'])) {
                $userPayload['password_hash'] = Hash::make((string) $data['password']);
            }

            if ($pengguna) {
                $pengguna->update($userPayload);
            } else {
                Pengguna::create(array_merge($userPayload, [
                    'id_karyawan'   => $karyawan->id_karyawan,
                    'password_hash' => $userPayload['password_hash'] ?? Hash::make('password123'),
                ]));
            }
        });

        return redirect()->route('admin.karyawan.index')->with('success', 'Data karyawan berhasil diperbarui.');
    }

    public function deactivate(Karyawan $karyawan): RedirectResponse
    {
        $karyawan->update(['status_aktif' => false]);

        Log::info('Admin menonaktifkan karyawan.', ['id_karyawan' => $karyawan->id_karyawan]);

        return redirect()->route('admin.karyawan.index')->with('success', 'Karyawan berhasil dinonaktifkan.');
    }

    public function resetFace(Karyawan $karyawan): RedirectResponse
    {
        $diskName = (string) config('face.storage_disk', 'private');
        $faces = DataWajah::where('id_karyawan', $karyawan->id_karyawan)->get();

        foreach ($faces as $face) {
            if ($face->foto_referensi) {
                Storage::disk($diskName)->delete($face->foto_referensi);
            }
        }

        DataWajah::where('id_karyawan', $karyawan->id_karyawan)->delete();

        Log::info('Admin mereset data wajah karyawan.', ['id_karyawan' => $karyawan->id_karyawan]);

        return redirect()->route('admin.karyawan.index')->with('success', 'Data wajah karyawan berhasil direset.');
    }

    public function resetDevice(Karyawan $karyawan): RedirectResponse
    {
        if ($karyawan->pengguna) {
            $karyawan->pengguna->update(['device_id' => null]);
        }

        Log::info('Admin mereset device_id karyawan.', ['id_karyawan' => $karyawan->id_karyawan]);

        return redirect()->route('admin.karyawan.index')->with('success', 'Perangkat karyawan berhasil direset.');
    }
}
