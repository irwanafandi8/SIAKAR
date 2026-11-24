@extends('layouts.admin')

@section('title', 'Tambah Jabatan — SIAKAR')
@section('header', 'Tambah Jabatan')

@section('content')
    <x-card class="max-w-lg">
        <form method="POST" action="{{ route('admin.jabatan.store') }}">
            @csrf
            <x-form-field name="nama_jabatan" label="Nama Jabatan" required />
            <div class="flex gap-2">
                <x-button>Simpan</x-button>
                <a href="{{ route('admin.jabatan.index') }}" class="px-4 py-2.5 border border-outline rounded-card text-sm font-semibold">Batal</a>
            </div>
        </form>
    </x-card>
@endsection
