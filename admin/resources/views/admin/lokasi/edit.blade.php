@extends('layouts.admin')
@section('title', 'Ubah Lokasi — SIAKAR')
@section('header', 'Ubah Lokasi Kantor')
@section('content')
    <x-card class="max-w-lg">
        <form method="POST" action="{{ route('admin.lokasi.update', $lokasi) }}">
            @csrf @method('PUT')
            <x-form-field name="nama_lokasi" label="Nama Lokasi" :value="$lokasi->nama_lokasi" required />
            <x-form-field name="latitude" label="Latitude" :value="$lokasi->latitude" required />
            <x-form-field name="longitude" label="Longitude" :value="$lokasi->longitude" required />
            <x-form-field name="radius_meter" label="Radius (meter)" type="number" :value="$lokasi->radius_meter" required />
            <div class="flex gap-2">
                <x-button>Perbarui</x-button>
                <a href="{{ route('admin.lokasi.index') }}" class="px-4 py-2.5 border border-outline rounded-card text-sm font-semibold">Batal</a>
            </div>
        </form>
    </x-card>
@endsection
