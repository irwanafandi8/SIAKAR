@props([
    'name',
    'label',
    'type' => 'text',
    'value' => '',
    'required' => false,
    'placeholder' => '',
])

<div class="mb-4">
    <label for="{{ $name }}" class="block text-sm font-semibold text-navy mb-1.5">
        {{ $label }}
        @if ($required)
            <span class="text-[#A32121]">*</span>
        @endif
    </label>

    @if ($type === 'select')
        <select id="{{ $name }}" name="{{ $name }}"
                {{ $required ? 'required' : '' }}
                {{ $attributes->merge(['class' => 'w-full px-3 py-2.5 bg-surface border border-outline rounded-input text-sm text-navy focus:outline-none focus:border-primary']) }}>
            {{ $slot }}
        </select>
    @elseif ($type === 'textarea')
        <textarea id="{{ $name }}" name="{{ $name }}"
                  placeholder="{{ $placeholder }}"
                  {{ $required ? 'required' : '' }}
                  {{ $attributes->merge(['class' => 'w-full px-3 py-2.5 bg-surface border border-outline rounded-input text-sm text-navy focus:outline-none focus:border-primary']) }}>{{ old($name, $value) }}</textarea>
    @else
        <input id="{{ $name }}" name="{{ $name }}" type="{{ $type }}"
               value="{{ $type === 'password' ? '' : old($name, $value) }}"
               placeholder="{{ $placeholder }}"
               {{ $required ? 'required' : '' }}
               {{ $attributes->merge(['class' => 'w-full px-3 py-2.5 bg-surface border border-outline rounded-input text-sm text-navy focus:outline-none focus:border-primary']) }}>
    @endif

    @error($name)
        <p class="mt-1 text-xs text-[#A32121]">{{ $message }}</p>
    @enderror
</div>
