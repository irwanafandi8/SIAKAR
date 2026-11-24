@extends('layouts.admin')

@section('title', 'Ubah Departemen — SIAKAR')
@section('header', 'Ubah Departemen')

@section('content')
    <x-card class="max-w-lg">
        <form method="POST" action="{{ route('admin.departemen.update', $departemen) }}">
            @csrf
            @method('PUT')
            <x-form-field name="nama_departemen" label="Nama Departemen" :value="$departemen->nama_departemen" required />
            <div class="flex gap-2">
                <x-button>Perbarui</x-button>
                <a href="{{ route('admin.departemen.index') }}" class="px-4 py-2.5 border border-outline rounded-card text-sm font-semibold">Batal</a>
            </div>
        </form>
    </x-card>
@endsection
