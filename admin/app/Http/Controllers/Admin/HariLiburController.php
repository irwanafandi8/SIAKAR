<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Models\HariLibur;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;
use Illuminate\View\View;

class HariLiburController extends Controller
{
    public function index(Request $request): View
    {
        $search = trim((string) $request->query('search', ''));
        $items = HariLibur::when($search !== '', fn ($q) => $q->where('keterangan', 'like', "%{$search}%"))
            ->orderByDesc('tanggal')
            ->paginate(10)
            ->withQueryString();

        return view('admin.hari-libur.index', compact('items', 'search'));
    }

    public function create(): View
    {
        return view('admin.hari-libur.create');
    }

    public function store(Request $request): RedirectResponse
    {
        $validated = $request->validate([
            'tanggal'    => ['required', 'date_format:Y-m-d', 'unique:hari_libur,tanggal'],
            'keterangan' => ['required', 'string', 'max:200'],
        ]);

        HariLibur::create($validated);

        return redirect()->route('admin.hari-libur.index')->with('success', 'Hari libur berhasil ditambahkan.');
    }

    public function edit(HariLibur $hariLibur): View
    {
        return view('admin.hari-libur.edit', compact('hariLibur'));
    }

    public function update(Request $request, HariLibur $hariLibur): RedirectResponse
    {
        $validated = $request->validate([
            'tanggal'    => ['required', 'date_format:Y-m-d', Rule::unique('hari_libur', 'tanggal')->ignore($hariLibur->id_libur, 'id_libur')],
            'keterangan' => ['required', 'string', 'max:200'],
        ]);

        $hariLibur->update($validated);

        return redirect()->route('admin.hari-libur.index')->with('success', 'Hari libur berhasil diperbarui.');
    }

    public function destroy(HariLibur $hariLibur): RedirectResponse
    {
        $hariLibur->delete();

        return redirect()->route('admin.hari-libur.index')->with('success', 'Hari libur berhasil dihapus.');
    }
}
