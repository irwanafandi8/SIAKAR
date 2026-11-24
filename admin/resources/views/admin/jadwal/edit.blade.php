@extends('layouts.admin')
@section('title', 'Ubah Jadwal — SIAKAR')
@section('header', 'Ubah Jadwal Karyawan')
@section('content')
    <x-card class="max-w-lg">
        <form method="POST" action="{{ route('admin.jadwal.update', $jadwal) }}">
            @csrf @method('PUT')
            <x-form-field name="id_karyawan" label="Karyawan" type="select" required>
                @foreach ($karyawanList as $k)
                    <option value="{{ $k->id_karyawan }}" @selected(old('id_karyawan', $jadwal->id_karyawan) == $k->id_karyawan)>{{ $k->nama }} ({{ $k->nik }})</option>
                @endforeach
            </x-form-field>
            <x-form-field name="id_shift" label="Shift" type="select" required>
                @foreach ($shiftList as $s)
                    <option value="{{ $s->id_shift }}" @selected(old('id_shift', $jadwal->id_shift) == $s->id_shift)>{{ $s->nama_shift }} ({{ $s->jam_masuk }} - {{ $s->jam_pulang }})</option>
                @endforeach
            </x-form-field>
            <x-form-field name="tanggal" label="Tanggal" type="date" :value="$jadwal->tanggal?->format('Y-m-d')" required />
            <div class="flex gap-2">
                <x-button>Perbarui</x-button>
                <a href="{{ route('admin.jadwal.index') }}" class="px-4 py-2.5 border border-outline rounded-card text-sm font-semibold">Batal</a>
            </div>
        </form>
    </x-card>
@endsection
