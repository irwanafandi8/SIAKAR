@extends('layouts.admin')
@section('title', 'Tambah Lokasi — SIAKAR')
@section('header', 'Tambah Lokasi Kantor')
@section('content')
    <x-card class="max-w-lg">
        <form method="POST" action="{{ route('admin.lokasi.store') }}">
            @csrf
            <x-form-field name="nama_lokasi" label="Nama Lokasi" required />
            <x-form-field name="latitude" label="Latitude" required />
            <x-form-field name="longitude" label="Longitude" required />
            <x-form-field name="radius_meter" label="Radius (meter)" type="number" value="100" required />
            <div class="flex gap-2">
                <x-button>Simpan</x-button>
                <a href="{{ route('admin.lokasi.index') }}" class="px-4 py-2.5 border border-outline rounded-card text-sm font-semibold">Batal</a>
            </div>
        </form>
    </x-card>
@endsection
