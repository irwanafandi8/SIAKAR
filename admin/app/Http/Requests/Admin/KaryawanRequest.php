<?php

namespace App\Http\Requests\Admin;

use App\Models\Pengguna;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class KaryawanRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    /**
     * @return array<string, mixed>
     */
    public function rules(): array
    {
        $karyawan = $this->route('karyawan');
        $idKaryawan = $karyawan?->id_karyawan;
        $idPengguna = $karyawan?->pengguna?->id_pengguna;

        return [
            'nik'           => ['required', 'string', 'max:30', Rule::unique('karyawan', 'nik')->ignore($idKaryawan, 'id_karyawan')],
            'nama'          => ['required', 'string', 'max:120'],
            'jenis_kelamin' => ['required', Rule::in(['L', 'P'])],
            'tanggal_lahir' => ['required', 'date'],
            'email'         => ['nullable', 'email', 'max:120'],
            'no_hp'         => ['nullable', 'string', 'max:30'],
            'alamat'        => ['nullable', 'string', 'max:500'],
            'tanggal_masuk' => ['required', 'date'],
            'id_departemen' => ['required', 'exists:departemen,id_departemen'],
            'id_jabatan'    => ['required', 'exists:jabatan,id_jabatan'],
            'id_atasan'     => ['nullable', 'exists:karyawan,id_karyawan'],
            'status_aktif'  => ['nullable', 'boolean'],
            'username'      => ['required', 'string', 'max:60', Rule::unique('pengguna', 'username')->ignore($idPengguna, 'id_pengguna')],
            'password'      => [$idKaryawan === null ? 'required' : 'nullable', 'string', 'min:6'],
            'role'          => ['required', Rule::in([Pengguna::ROLE_KARYAWAN, Pengguna::ROLE_ATASAN, Pengguna::ROLE_ADMIN])],
        ];
    }
}
