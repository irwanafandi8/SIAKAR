@extends('layouts.admin')

@section('title', 'Tambah Karyawan — SIAKAR')
@section('header', 'Tambah Karyawan')

@section('content')
    <x-card class="max-w-2xl">
        <form method="POST" action="{{ route('admin.karyawan.store') }}">
            @csrf
            <div class="grid grid-cols-1 md:grid-cols-2 gap-x-4">
                <x-form-field name="nik" label="NIK" required />
                <x-form-field name="nama" label="Nama Lengkap" required />

                <x-form-field name="jenis_kelamin" label="Jenis Kelamin" type="select" required>
                    <option value="L" @selected(old('jenis_kelamin') === 'L')>Laki-laki</option>
                    <option value="P" @selected(old('jenis_kelamin') === 'P')>Perempuan</option>
                </x-form-field>

                <x-form-field name="tanggal_lahir" label="Tanggal Lahir" type="date" required />
                <x-form-field name="tanggal_masuk" label="Tanggal Masuk" type="date" required />
                <x-form-field name="email" label="Email" type="email" />
                <x-form-field name="no_hp" label="No. HP" />

                <x-form-field name="id_departemen" label="Departemen" type="select" required>
                    <option value="">-- Pilih Departemen --</option>
                    @foreach ($departemenList as $dept)
                        <option value="{{ $dept->id_departemen }}" @selected(old('id_departemen') == $dept->id_departemen)>
                            {{ $dept->nama_departemen }}
                        </option>
                    @endforeach
                </x-form-field>

                <x-form-field name="id_jabatan" label="Jabatan" type="select" required>
                    <option value="">-- Pilih Jabatan --</option>
                    @foreach ($jabatanList as $jab)
                        <option value="{{ $jab->id_jabatan }}" @selected(old('id_jabatan') == $jab->id_jabatan)>
                            {{ $jab->nama_jabatan }}
                        </option>
                    @endforeach
                </x-form-field>

                <x-form-field name="id_atasan" label="Atasan Langsung" type="select">
                    <option value="">-- Tidak Ada --</option>
                    @foreach ($atasanList as $atasan)
                        <option value="{{ $atasan->id_karyawan }}" @selected(old('id_atasan') == $atasan->id_karyawan)>
                            {{ $atasan->nama }} ({{ $atasan->nik }})
                        </option>
                    @endforeach
                </x-form-field>
            </div>

            <x-form-field name="alamat" label="Alamat" type="textarea" />

            <hr class="my-4 border-outline">
            <h3 class="text-sm font-bold text-navy mb-3">Akun Pengguna</h3>
            <div class="grid grid-cols-1 md:grid-cols-3 gap-x-4">
                <x-form-field name="username" label="Username" required />
                <x-form-field name="password" label="Password" type="password" required />
                <x-form-field name="role" label="Peran" type="select" required>
                    <option value="karyawan" @selected(old('role', 'karyawan') === 'karyawan')>Karyawan</option>
                    <option value="atasan" @selected(old('role') === 'atasan')>Atasan</option>
                    <option value="admin" @selected(old('role') === 'admin')>Admin</option>
                </x-form-field>
            </div>

            <div class="flex gap-2 mt-2">
                <x-button>Simpan</x-button>
                <a href="{{ route('admin.karyawan.index') }}" class="px-4 py-2.5 border border-outline rounded-card text-sm font-semibold">Batal</a>
            </div>
        </form>
    </x-card>
@endsection
