@extends('layouts.admin')
@section('title', 'Ubah Hari Libur — SIAKAR')
@section('header', 'Ubah Hari Libur')
@section('content')
    <x-card class="max-w-lg">
        <form method="POST" action="{{ route('admin.hari-libur.update', $hariLibur) }}">
            @csrf @method('PUT')
            <x-form-field name="tanggal" label="Tanggal" type="date" :value="$hariLibur->tanggal?->format('Y-m-d')" required />
            <x-form-field name="keterangan" label="Keterangan" :value="$hariLibur->keterangan" required />
            <div class="flex gap-2">
                <x-button>Perbarui</x-button>
                <a href="{{ route('admin.hari-libur.index') }}" class="px-4 py-2.5 border border-outline rounded-card text-sm font-semibold">Batal</a>
            </div>
        </form>
    </x-card>
@endsection
