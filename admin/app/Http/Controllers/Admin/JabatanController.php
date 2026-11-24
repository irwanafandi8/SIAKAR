<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Models\Jabatan;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\View\View;

class JabatanController extends Controller
{
    public function index(Request $request): View
    {
        $search = trim((string) $request->query('search', ''));
        $items = Jabatan::when($search !== '', function ($q) use ($search): void {
            $q->where('nama_jabatan', 'like', "%{$search}%");
        })
            ->orderBy('nama_jabatan')
            ->paginate(10)
            ->withQueryString();

        return view('admin.jabatan.index', compact('items', 'search'));
    }

    public function create(): View
    {
        return view('admin.jabatan.create');
    }

    public function store(Request $request): RedirectResponse
    {
        $validated = $request->validate([
            'nama_jabatan' => ['required', 'string', 'max:100', 'unique:jabatan,nama_jabatan'],
        ]);

        Jabatan::create($validated);

        return redirect()->route('admin.jabatan.index')->with('success', 'Jabatan berhasil ditambahkan.');
    }

    public function edit(Jabatan $jabatan): View
    {
        return view('admin.jabatan.edit', compact('jabatan'));
    }

    public function update(Request $request, Jabatan $jabatan): RedirectResponse
    {
        $validated = $request->validate([
            'nama_jabatan' => ['required', 'string', 'max:100', 'unique:jabatan,nama_jabatan,' . $jabatan->id_jabatan . ',id_jabatan'],
        ]);

        $jabatan->update($validated);

        return redirect()->route('admin.jabatan.index')->with('success', 'Jabatan berhasil diperbarui.');
    }

    public function destroy(Jabatan $jabatan): RedirectResponse
    {
        $jabatan->delete();

        return redirect()->route('admin.jabatan.index')->with('success', 'Jabatan berhasil dihapus.');
    }
}
