@props(['title' => null])

<div {{ $attributes->merge(['class' => 'bg-surface border border-outline rounded-card p-5']) }}>
    @if ($title)
        <h2 class="text-base font-semibold text-navy mb-4">{{ $title }}</h2>
    @endif
    {{ $slot }}
</div>
