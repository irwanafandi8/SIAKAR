@extends('layouts.admin')

@section('title', 'Ubah Jabatan — SIAKAR')
@section('header', 'Ubah Jabatan')

@section('content')
    <x-card class="max-w-lg">
        <form method="POST" action="{{ route('admin.jabatan.update', $jabatan) }}">
            @csrf
            @method('PUT')
            <x-form-field name="nama_jabatan" label="Nama Jabatan" :value="$jabatan->nama_jabatan" required />
            <div class="flex gap-2">
                <x-button>Perbarui</x-button>
                <a href="{{ route('admin.jabatan.index') }}" class="px-4 py-2.5 border border-outline rounded-card text-sm font-semibold">Batal</a>
            </div>
        </form>
    </x-card>
@endsection
