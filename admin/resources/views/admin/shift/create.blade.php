@extends('layouts.admin')
@section('title', 'Tambah Shift — SIAKAR')
@section('header', 'Tambah Shift')
@section('content')
    <x-card class="max-w-lg">
        <form method="POST" action="{{ route('admin.shift.store') }}">
            @csrf
            <x-form-field name="nama_shift" label="Nama Shift" required />
            <x-form-field name="jam_masuk" label="Jam Masuk (HH:MM:SS)" placeholder="08:00:00" required />
            <x-form-field name="jam_pulang" label="Jam Pulang (HH:MM:SS)" placeholder="16:00:00" required />
            <x-form-field name="toleransi_menit" label="Toleransi (menit)" type="number" value="10" required />
            <div class="flex gap-2">
                <x-button>Simpan</x-button>
                <a href="{{ route('admin.shift.index') }}" class="px-4 py-2.5 border border-outline rounded-card text-sm font-semibold">Batal</a>
            </div>
        </form>
    </x-card>
@endsection
