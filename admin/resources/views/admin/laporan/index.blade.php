@extends('layouts.admin')
@section('title', 'Laporan & Ekspor CSV — SIAKAR')
@section('header', 'Rekap Laporan Absensi')
@section('content')
    <div class="flex flex-wrap items-end justify-between gap-4 mb-4">
        <form method="GET" action="{{ route('admin.laporan.index') }}" class="flex flex-wrap items-end gap-2">
            <div>
                <label class="block text-xs font-semibold text-navy mb-1">Dari</label>
                <input type="date" name="from" value="{{ $from }}" class="px-3 py-2 bg-surface border border-outline rounded-input text-sm">
            </div>
            <div>
                <label class="block text-xs font-semibold text-navy mb-1">Sampai</label>
                <input type="date" name="to" value="{{ $to }}" class="px-3 py-2 bg-surface border border-outline rounded-input text-sm">
            </div>
            <div>
                <label class="block text-xs font-semibold text-navy mb-1">Departemen</label>
                <select name="id_departemen" class="px-3 py-2 bg-surface border border-outline rounded-input text-sm">
                    <option value="">Semua</option>
                    @foreach ($departemenList as $d)
                        <option value="{{ $d->id_departemen }}" @selected($idDepartemen == $d->id_departemen)>{{ $d->nama_departemen }}</option>
                    @endforeach
                </select>
            </div>
            <x-button variant="secondary">Tampilkan</x-button>
        </form>

        <a href="{{ route('admin.laporan.export-csv', request()->query()) }}"
           class="px-4 py-2.5 bg-primary text-white rounded-card text-sm font-semibold hover:bg-primary-dark">
            Ekspor CSV
        </a>
    </div>

    <x-table :headers="['NIK', 'Nama', 'Departemen', 'Hadir', 'Terlambat', 'Izin', 'Sakit', 'Cuti', 'Alpa']">
        @forelse ($rows as $row)
            <tr class="hover:bg-tint">
                <td class="px-4 py-3 font-mono text-xs">{{ $row['nik'] }}</td>
                <td class="px-4 py-3 font-medium">{{ $row['nama'] }}</td>
                <td class="px-4 py-3 text-xs">{{ $row['departemen'] }}</td>
                <td class="px-4 py-3">{{ $row['hadir'] }}</td>
                <td class="px-4 py-3">{{ $row['terlambat'] }}</td>
                <td class="px-4 py-3">{{ $row['izin'] }}</td>
                <td class="px-4 py-3">{{ $row['sakit'] }}</td>
                <td class="px-4 py-3">{{ $row['cuti'] }}</td>
                <td class="px-4 py-3">{{ $row['alpa'] }}</td>
            </tr>
        @empty
            <tr><td colspan="9" class="px-4 py-6 text-center text-muted">Tidak ada data rekap.</td></tr>
        @endforelse
    </x-table>
@endsection
