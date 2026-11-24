@props(['headers' => []])

<div class="overflow-x-auto border border-outline rounded-card bg-surface">
    <table class="w-full text-sm text-left">
        @if (!empty($headers))
            <thead class="bg-navy text-white">
                <tr>
                    @foreach ($headers as $header)
                        <th class="px-4 py-3 font-semibold">{{ $header }}</th>
                    @endforeach
                </tr>
            </thead>
        @endif
        <tbody class="divide-y divide-outline">
            {{ $slot }}
        </tbody>
    </table>
</div>
