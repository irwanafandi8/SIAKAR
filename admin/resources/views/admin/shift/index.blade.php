@extends('layouts.admin')
@section('title', 'Shift — SIAKAR')
@section('header', 'Data Shift')
@section('content')
    <div class="flex flex-wrap items-center justify-between gap-4 mb-4">
        <form method="GET" action="{{ route('admin.shift.index') }}" class="flex gap-2">
            <input type="text" name="search" value="{{ $search }}" placeholder="Cari shift..." class="px-3 py-2 bg-surface border border-outline rounded-input text-sm text-navy">
            <x-button variant="secondary">Cari</x-button>
        </form>
        <a href="{{ route('admin.shift.create') }}" class="px-4 py-2.5 bg-primary text-white rounded-card text-sm font-semibold hover:bg-primary-dark">+ Tambah Shift</a>
    </div>
    <x-table :headers="['Nama Shift', 'Jam Masuk', 'Jam Pulang', 'Toleransi (menit)', 'Aksi']">
        @forelse ($items as $item)
            <tr class="hover:bg-tint">
                <td class="px-4 py-3 font-medium">{{ $item->nama_shift }}</td>
                <td class="px-4 py-3">{{ $item->jam_masuk }}</td>
                <td class="px-4 py-3">{{ $item->jam_pulang }}</td>
                <td class="px-4 py-3">{{ $item->toleransi_menit }}</td>
                <td class="px-4 py-3 flex items-center gap-2">
                    <a href="{{ route('admin.shift.edit', $item) }}" class="text-primary font-semibold hover:underline">Ubah</a>
                    <form method="POST" action="{{ route('admin.shift.destroy', $item) }}" onsubmit="return confirm('Hapus shift ini?')">
                        @csrf @method('DELETE')
                        <button type="submit" class="text-[#A32121] font-semibold hover:underline">Hapus</button>
                    </form>
                </td>
            </tr>
        @empty
            <tr><td colspan="5" class="px-4 py-6 text-center text-muted">Belum ada data shift.</td></tr>
        @endforelse
    </x-table>
    <div class="mt-4">{{ $items->links() }}</div>
@endsection
