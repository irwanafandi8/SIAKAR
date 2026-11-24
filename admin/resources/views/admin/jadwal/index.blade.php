@extends('layouts.admin')
@section('title', 'Jadwal Karyawan — SIAKAR')
@section('header', 'Jadwal Karyawan')
@section('content')
    <div class="flex flex-wrap items-center justify-between gap-4 mb-4">
        <form method="GET" action="{{ route('admin.jadwal.index') }}" class="flex gap-2">
            <input type="text" name="search" value="{{ $search }}" placeholder="Cari nama/NIK..." class="px-3 py-2 bg-surface border border-outline rounded-input text-sm text-navy">
            <x-button variant="secondary">Cari</x-button>
        </form>
        <a href="{{ route('admin.jadwal.create') }}" class="px-4 py-2.5 bg-primary text-white rounded-card text-sm font-semibold hover:bg-primary-dark">+ Tambah Jadwal</a>
    </div>
    <x-table :headers="['Tanggal', 'Karyawan', 'Shift', 'Aksi']">
        @forelse ($items as $item)
            <tr class="hover:bg-tint">
                <td class="px-4 py-3">{{ $item->tanggal?->format('Y-m-d') }}</td>
                <td class="px-4 py-3 font-medium">{{ $item->karyawan?->nama }} ({{ $item->karyawan?->nik }})</td>
                <td class="px-4 py-3">{{ $item->shift?->nama_shift }}</td>
                <td class="px-4 py-3 flex items-center gap-2">
                    <a href="{{ route('admin.jadwal.edit', $item) }}" class="text-primary font-semibold hover:underline">Ubah</a>
                    <form method="POST" action="{{ route('admin.jadwal.destroy', $item) }}" onsubmit="return confirm('Hapus jadwal ini?')">
                        @csrf @method('DELETE')
                        <button type="submit" class="text-[#A32121] font-semibold hover:underline">Hapus</button>
                    </form>
                </td>
            </tr>
        @empty
            <tr><td colspan="4" class="px-4 py-6 text-center text-muted">Belum ada data jadwal.</td></tr>
        @endforelse
    </x-table>
    <div class="mt-4">{{ $items->links() }}</div>
@endsection
