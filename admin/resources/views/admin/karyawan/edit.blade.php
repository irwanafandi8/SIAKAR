@extends('layouts.admin')

@section('title', 'Ubah Karyawan — SIAKAR')
@section('header', 'Ubah Karyawan')

@section('content')
    <x-card class="max-w-2xl">
        <form method="POST" action="{{ route('admin.karyawan.update', $karyawan) }}">
            @csrf
            @method('PUT')
            <div class="grid grid-cols-1 md:grid-cols-2 gap-x-4">
                <x-form-field name="nik" label="NIK" :value="$karyawan->nik" required />
                <x-form-field name="nama" label="Nama Lengkap" :value="$karyawan->nama" required />

                <x-form-field name="jenis_kelamin" label="Jenis Kelamin" type="select" required>
                    <option value="L" @selected(old('jenis_kelamin', $karyawan->jenis_kelamin) === 'L')>Laki-laki</option>
                    <option value="P" @selected(old('jenis_kelamin', $karyawan->jenis_kelamin) === 'P')>Perempuan</option>
                </x-form-field>

                <x-form-field name="tanggal_lahir" label="Tanggal Lahir" type="date" :value="$karyawan->tanggal_lahir?->format('Y-m-d')" required />
                <x-form-field name="tanggal_masuk" label="Tanggal Masuk" type="date" :value="$karyawan->tanggal_masuk?->format('Y-m-d')" required />
                <x-form-field name="email" label="Email" type="email" :value="$karyawan->email" />
                <x-form-field name="no_hp" label="No. HP" :value="$karyawan->no_hp" />

                <x-form-field name="id_departemen" label="Departemen" type="select" required>
                    @foreach ($departemenList as $dept)
                        <option value="{{ $dept->id_departemen }}" @selected(old('id_departemen', $karyawan->id_departemen) == $dept->id_departemen)>
                            {{ $dept->nama_departemen }}
                        </option>
                    @endforeach
                </x-form-field>

                <x-form-field name="id_jabatan" label="Jabatan" type="select" required>
                    @foreach ($jabatanList as $jab)
                        <option value="{{ $jab->id_jabatan }}" @selected(old('id_jabatan', $karyawan->id_jabatan) == $jab->id_jabatan)>
                            {{ $jab->nama_jabatan }}
                        </option>
                    @endforeach
                </x-form-field>

                <x-form-field name="id_atasan" label="Atasan Langsung" type="select">
                    <option value="">-- Tidak Ada --</option>
                    @foreach ($atasanList as $atasan)
                        <option value="{{ $atasan->id_karyawan }}" @selected(old('id_atasan', $karyawan->id_atasan) == $atasan->id_karyawan)>
                            {{ $atasan->nama }} ({{ $atasan->nik }})
                        </option>
                    @endforeach
                </x-form-field>

                <x-form-field name="status_aktif" label="Status Aktif" type="select">
                    <option value="1" @selected((string) old('status_aktif', $karyawan->status_aktif ? '1' : '0') === '1')>Aktif</option>
                    <option value="0" @selected((string) old('status_aktif', $karyawan->status_aktif ? '1' : '0') === '0')>Nonaktif</option>
                </x-form-field>
            </div>

            <x-form-field name="alamat" label="Alamat" type="textarea" :value="$karyawan->alamat" />

            <hr class="my-4 border-outline">
            <h3 class="text-sm font-bold text-navy mb-3">Akun Pengguna</h3>
            <div class="grid grid-cols-1 md:grid-cols-3 gap-x-4">
                <x-form-field name="username" label="Username" :value="$karyawan->pengguna?->username" required />
                <x-form-field name="password" label="Password Baru (opsional)" type="password" />
                <x-form-field name="role" label="Peran" type="select" required>
                    @php($currentRole = old('role', $karyawan->pengguna?->role ?? 'karyawan'))
                    <option value="karyawan" @selected($currentRole === 'karyawan')>Karyawan</option>
                    <option value="atasan" @selected($currentRole === 'atasan')>Atasan</option>
                    <option value="admin" @selected($currentRole === 'admin')>Admin</option>
                </x-form-field>
            </div>

            <div class="flex gap-2 mt-2">
                <x-button>Perbarui</x-button>
                <a href="{{ route('admin.karyawan.index') }}" class="px-4 py-2.5 border border-outline rounded-card text-sm font-semibold">Batal</a>
            </div>
        </form>
    </x-card>
@endsection
