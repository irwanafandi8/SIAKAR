@extends('layouts.admin')
@section('title', 'Tambah Hari Libur — SIAKAR')
@section('header', 'Tambah Hari Libur')
@section('content')
    <x-card class="max-w-lg">
        <form method="POST" action="{{ route('admin.hari-libur.store') }}">
            @csrf
            <x-form-field name="tanggal" label="Tanggal" type="date" required />
            <x-form-field name="keterangan" label="Keterangan" required />
            <div class="flex gap-2">
                <x-button>Simpan</x-button>
                <a href="{{ route('admin.hari-libur.index') }}" class="px-4 py-2.5 border border-outline rounded-card text-sm font-semibold">Batal</a>
            </div>
        </form>
    </x-card>
@endsection
