@extends('layouts.admin')
@section('title', 'Hari Libur — SIAKAR')
@section('header', 'Hari Libur')
@section('content')
    <div class="flex flex-wrap items-center justify-between gap-4 mb-4">
        <form method="GET" action="{{ route('admin.hari-libur.index') }}" class="flex gap-2">
            <input type="text" name="search" value="{{ $search }}" placeholder="Cari keterangan..." class="px-3 py-2 bg-surface border border-outline rounded-input text-sm text-navy">
            <x-button variant="secondary">Cari</x-button>
        </form>
        <a href="{{ route('admin.hari-libur.create') }}" class="px-4 py-2.5 bg-primary text-white rounded-card text-sm font-semibold hover:bg-primary-dark">+ Tambah Hari Libur</a>
    </div>
    <x-table :headers="['Tanggal', 'Keterangan', 'Aksi']">
        @forelse ($items as $item)
            <tr class="hover:bg-tint">
                <td class="px-4 py-3">{{ $item->tanggal?->format('Y-m-d') }}</td>
                <td class="px-4 py-3 font-medium">{{ $item->keterangan }}</td>
                <td class="px-4 py-3 flex items-center gap-2">
                    <a href="{{ route('admin.hari-libur.edit', $item) }}" class="text-primary font-semibold hover:underline">Ubah</a>
                    <form method="POST" action="{{ route('admin.hari-libur.destroy', $item) }}" onsubmit="return confirm('Hapus hari libur ini?')">
                        @csrf @method('DELETE')
                        <button type="submit" class="text-[#A32121] font-semibold hover:underline">Hapus</button>
                    </form>
                </td>
            </tr>
        @empty
            <tr><td colspan="3" class="px-4 py-6 text-center text-muted">Belum ada data hari libur.</td></tr>
        @endforelse
    </x-table>
    <div class="mt-4">{{ $items->links() }}</div>
@endsection
