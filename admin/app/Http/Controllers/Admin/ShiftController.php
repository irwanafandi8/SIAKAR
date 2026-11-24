<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Models\Shift;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\View\View;

class ShiftController extends Controller
{
    public function index(Request $request): View
    {
        $search = trim((string) $request->query('search', ''));
        $items = Shift::when($search !== '', fn ($q) => $q->where('nama_shift', 'like', "%{$search}%"))
            ->orderBy('nama_shift')
            ->paginate(10)
            ->withQueryString();

        return view('admin.shift.index', compact('items', 'search'));
    }

    public function create(): View
    {
        return view('admin.shift.create');
    }

    public function store(Request $request): RedirectResponse
    {
        $validated = $request->validate([
            'nama_shift'      => ['required', 'string', 'max:60'],
            'jam_masuk'       => ['required', 'regex:/^\d{2}:\d{2}(:\d{2})?$/'],
            'jam_pulang'      => ['required', 'regex:/^\d{2}:\d{2}(:\d{2})?$/'],
            'toleransi_menit' => ['required', 'integer', 'min:0', 'max:180'],
        ]);

        Shift::create($validated);

        return redirect()->route('admin.shift.index')->with('success', 'Shift berhasil ditambahkan.');
    }

    public function edit(Shift $shift): View
    {
        return view('admin.shift.edit', compact('shift'));
    }

    public function update(Request $request, Shift $shift): RedirectResponse
    {
        $validated = $request->validate([
            'nama_shift'      => ['required', 'string', 'max:60'],
            'jam_masuk'       => ['required', 'regex:/^\d{2}:\d{2}(:\d{2})?$/'],
            'jam_pulang'      => ['required', 'regex:/^\d{2}:\d{2}(:\d{2})?$/'],
            'toleransi_menit' => ['required', 'integer', 'min:0', 'max:180'],
        ]);

        $shift->update($validated);

        return redirect()->route('admin.shift.index')->with('success', 'Shift berhasil diperbarui.');
    }

    public function destroy(Shift $shift): RedirectResponse
    {
        $shift->delete();

        return redirect()->route('admin.shift.index')->with('success', 'Shift berhasil dihapus.');
    }
}
