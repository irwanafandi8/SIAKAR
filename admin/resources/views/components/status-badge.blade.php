@props(['status'])

@php
    $normalized = strtolower((string) $status);
    $classes = match ($normalized) {
        'hadir', 'aktif', 'disetujui' => 'bg-[#E3F3E7] text-[#1F6B33]',
        'terlambat' => 'bg-[#FFF1D6] text-[#9A5B00]',
        'izin', 'sakit', 'cuti' => 'bg-[#E1ECFA] text-[#1F4E8C]',
        'alpa', 'ditolak', 'nonaktif', 'error' => 'bg-[#FBE3E3] text-[#A32121]',
        default => 'bg-[#ECECF4] text-[#5B5B7A]',
    };
@endphp

<span {{ $attributes->merge(['class' => "inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-semibold {$classes}"]) }}>
    {{ ucfirst($normalized) }}
</span>
