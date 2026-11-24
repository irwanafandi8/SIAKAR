@extends('layouts.admin')
@section('title', 'Koreksi Absensi — SIAKAR')
@section('header', 'Koreksi Status Absensi')
@section('content')
    <x-card class="max-w-lg">
        <p class="text-sm text-muted mb-4">
            {{ $absensi->karyawan?->nama }} — {{ $absensi->tanggal?->format('Y-m-d') }}
        </p>
        <form method="POST" action="{{ route('admin.absensi.update', $absensi) }}">
            @csrf @method('PUT')
            <x-form-field name="status" label="Status Kehadiran" type="select" required>
                @foreach (['hadir', 'terlambat', 'izin', 'sakit', 'cuti', 'alpa'] as $st)
                    <option value="{{ $st }}" @selected(old('status', $absensi->status) === $st)>{{ ucfirst($st) }}</option>
                @endforeach
            </x-form-field>
            <x-form-field name="keterangan" label="Keterangan Koreksi (Wajib)" type="textarea" :value="$absensi->keterangan" required />
            <div class="flex gap-2">
                <x-button>Simpan Koreksi</x-button>
                <a href="{{ route('admin.absensi.index') }}" class="px-4 py-2.5 border border-outline rounded-card text-sm font-semibold">Batal</a>
            </div>
        </form>
    </x-card>
@endsection
