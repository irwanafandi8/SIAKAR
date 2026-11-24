@extends('layouts.admin')

@section('title', 'Tambah Departemen — SIAKAR')
@section('header', 'Tambah Departemen')

@section('content')
    <x-card class="max-w-lg">
        <form method="POST" action="{{ route('admin.departemen.store') }}">
            @csrf
            <x-form-field name="nama_departemen" label="Nama Departemen" required />
            <div class="flex gap-2">
                <x-button>Simpan</x-button>
                <a href="{{ route('admin.departemen.index') }}" class="px-4 py-2.5 border border-outline rounded-card text-sm font-semibold">Batal</a>
            </div>
        </form>
    </x-card>
@endsection
