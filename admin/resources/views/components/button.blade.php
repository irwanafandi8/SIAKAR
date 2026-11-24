@props([
    'variant' => 'primary',
    'type' => 'submit',
])

@php
    $classes = match ($variant) {
        'secondary' => 'bg-surface text-navy border border-outline hover:bg-tint',
        'danger' => 'bg-[#A32121] text-white hover:opacity-90',
        default => 'bg-primary text-white hover:bg-primary-dark',
    };
@endphp

<button type="{{ $type }}" {{ $attributes->merge(['class' => "inline-flex items-center justify-center px-4 py-2.5 rounded-card text-sm font-semibold transition min-h-[44px] {$classes}"]) }}>
    {{ $slot }}
</button>
