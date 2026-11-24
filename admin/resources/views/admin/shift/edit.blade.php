@extends('layouts.admin')
@section('title', 'Ubah Shift — SIAKAR')
@section('header', 'Ubah Shift')
@section('content')
    <x-card class="max-w-lg">
        <form method="POST" action="{{ route('admin.shift.update', $shift) }}">
            @csrf @method('PUT')
            <x-form-field name="nama_shift" label="Nama Shift" :value="$shift->nama_shift" required />
            <x-form-field name="jam_masuk" label="Jam Masuk (HH:MM:SS)" :value="$shift->jam_masuk" required />
            <x-form-field name="jam_pulang" label="Jam Pulang (HH:MM:SS)" :value="$shift->jam_pulang" required />
            <x-form-field name="toleransi_menit" label="Toleransi (menit)" type="number" :value="$shift->toleransi_menit" required />
            <div class="flex gap-2">
                <x-button>Perbarui</x-button>
                <a href="{{ route('admin.shift.index') }}" class="px-4 py-2.5 border border-outline rounded-card text-sm font-semibold">Batal</a>
            </div>
        </form>
    </x-card>
@endsection
