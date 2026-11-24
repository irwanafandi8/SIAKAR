@extends('layouts.admin')

@section('title', 'Karyawan — SIAKAR')
@section('header', 'Data Karyawan')

@section('content')
    <div class="flex flex-wrap items-center justify-between gap-4 mb-4">
        <form method="GET" action="{{ route('admin.karyawan.index') }}" class="flex gap-2">
            <input type="text" name="search" value="{{ $search }}" placeholder="Cari nama atau NIK..."
                   class="px-3 py-2 bg-surface border border-outline rounded-input text-sm text-navy">
            <x-button variant="secondary">Cari</x-button>
        </form>
        <a href="{{ route('admin.karyawan.create') }}"
           class="px-4 py-2.5 bg-primary text-white rounded-card text-sm font-semibold hover:bg-primary-dark">
            + Tambah Karyawan
        </a>
    </div>

    <x-table :headers="['NIK', 'Nama', 'Departemen / Jabatan', 'Atasan', 'Peran', 'Status', 'Aksi']">
        @forelse ($items as $item)
            <tr class="hover:bg-tint">
                <td class="px-4 py-3 font-mono text-xs">{{ $item->nik }}</td>
                <td class="px-4 py-3 font-medium">{{ $item->nama }}</td>
                <td class="px-4 py-3 text-xs">
                    {{ $item->departemen?->nama_departemen ?? '-' }}<br>
                    <span class="text-muted">{{ $item->jabatan?->nama_jabatan ?? '-' }}</span>
                </td>
                <td class="px-4 py-3 text-xs">{{ $item->atasan?->nama ?? '-' }}</td>
                <td class="px-4 py-3 text-xs">{{ ucfirst($item->pengguna?->role ?? '-') }}</td>
                <td class="px-4 py-3">
                    <x-status-badge :status="$item->status_aktif ? 'aktif' : 'nonaktif'" />
                </td>
                <td class="px-4 py-3">
                    <div class="flex flex-wrap items-center gap-2 text-xs">
                        <a href="{{ route('admin.karyawan.edit', $item) }}" class="text-primary font-semibold hover:underline">Ubah</a>

                        @if ($item->status_aktif)
                            <form method="POST" action="{{ route('admin.karyawan.deactivate', $item) }}"
                                  onsubmit="return confirm('Nonaktifkan karyawan ini?')">
                                @csrf
                                <button type="submit" class="text-[#A32121] font-semibold hover:underline">Nonaktifkan</button>
                            </form>
                        @endif

                        <form method="POST" action="{{ route('admin.karyawan.reset-face', $item) }}"
                              onsubmit="return confirm('Reset data wajah karyawan ini?')">
                            @csrf
                            <button type="submit" class="text-navy font-semibold hover:underline">Reset Wajah</button>
                        </form>

                        <form method="POST" action="{{ route('admin.karyawan.reset-device', $item) }}"
                              onsubmit="return confirm('Reset perangkat terikat karyawan ini?')">
                            @csrf
                            <button type="submit" class="text-navy font-semibold hover:underline">Reset Perangkat</button>
                        </form>
                    </div>
                </td>
            </tr>
        @empty
            <tr>
                <td colspan="7" class="px-4 py-6 text-center text-muted">Belum ada data karyawan.</td>
            </tr>
        @endforelse
    </x-table>

    <div class="mt-4">{{ $items->links() }}</div>
@endsection
