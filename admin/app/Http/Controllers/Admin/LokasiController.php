<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Models\LokasiKantor;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\View\View;

class LokasiController extends Controller
{
    public function index(Request $request): View
    {
        $search = trim((string) $request->query('search', ''));
        $items = LokasiKantor::when($search !== '', fn ($q) => $q->where('nama_lokasi', 'like', "%{$search}%"))
            ->orderBy('nama_lokasi')
            ->paginate(10)
            ->withQueryString();

        return view('admin.lokasi.index', compact('items', 'search'));
    }

    public function create(): View
    {
        return view('admin.lokasi.create');
    }

    public function store(Request $request): RedirectResponse
    {
        $validated = $request->validate([
            'nama_lokasi'  => ['required', 'string', 'max:120'],
            'latitude'     => ['required', 'numeric', 'between:-90,90'],
            'longitude'    => ['required', 'numeric', 'between:-180,180'],
            'radius_meter' => ['required', 'integer', 'min:10', 'max:10000'],
        ]);

        LokasiKantor::create($validated);

        return redirect()->route('admin.lokasi.index')->with('success', 'Lokasi kantor berhasil ditambahkan.');
    }

    public function edit(LokasiKantor $lokasi): View
    {
        return view('admin.lokasi.edit', compact('lokasi'));
    }

    public function update(Request $request, LokasiKantor $lokasi): RedirectResponse
    {
        $validated = $request->validate([
            'nama_lokasi'  => ['required', 'string', 'max:120'],
            'latitude'     => ['required', 'numeric', 'between:-90,90'],
            'longitude'    => ['required', 'numeric', 'between:-180,180'],
            'radius_meter' => ['required', 'integer', 'min:10', 'max:10000'],
        ]);

        $lokasi->update($validated);

        return redirect()->route('admin.lokasi.index')->with('success', 'Lokasi kantor berhasil diperbarui.');
    }

    public function destroy(LokasiKantor $lokasi): RedirectResponse
    {
        $lokasi->delete();

        return redirect()->route('admin.lokasi.index')->with('success', 'Lokasi kantor berhasil dihapus.');
    }
}
