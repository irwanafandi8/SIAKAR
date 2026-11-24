@extends('layouts.admin')
@section('title', 'Koreksi Absensi — SIAKAR')
@section('header', 'Monitoring & Koreksi Absensi')
@section('content')
    <form method="GET" action="{{ route('admin.absensi.index') }}" class="flex flex-wrap gap-2 mb-4">
        <input type="text" name="search" value="{{ $search }}" placeholder="Cari nama atau NIK..." class="px-3 py-2 bg-surface border border-outline rounded-input text-sm text-navy">
        <input type="date" name="tanggal" value="{{ $tanggal }}" class="px-3 py-2 bg-surface border border-outline rounded-input text-sm text-navy">
        <x-button variant="secondary">Filter</x-button>
    </form>
    <x-table :headers="['Tanggal', 'Karyawan', 'Jam Masuk', 'Jam Pulang', 'Status', 'Keterangan', 'Aksi']">
        @forelse ($items as $item)
            <tr class="hover:bg-tint">
                <td class="px-4 py-3">{{ $item->tanggal?->format('Y-m-d') }}</td>
                <td class="px-4 py-3 font-medium">{{ $item->karyawan?->nama }} ({{ $item->karyawan?->nik }})</td>
                <td class="px-4 py-3">{{ $item->jam_masuk ?? '-' }}</td>
                <td class="px-4 py-3">{{ $item->jam_pulang ?? '-' }}</td>
                <td class="px-4 py-3"><x-status-badge :status="$item->status" /></td>
                <td class="px-4 py-3 text-xs">{{ $item->keterangan ?? '-' }}</td>
                <td class="px-4 py-3">
                    <a href="{{ route('admin.absensi.edit', $item) }}" class="text-primary font-semibold hover:underline">Koreksi</a>
                </td>
            </tr>
        @empty
            <tr><td colspan="7" class="px-4 py-6 text-center text-muted">Belum ada data absensi.</td></tr>
        @endforelse
    </x-table>
    <div class="mt-4">{{ $items->links() }}</div>
@endsection
