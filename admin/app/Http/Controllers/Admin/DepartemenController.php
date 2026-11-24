<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Models\Departemen;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\View\View;

class DepartemenController extends Controller
{
    public function index(Request $request): View
    {
        $search = trim((string) $request->query('search', ''));
        $items = Departemen::when($search !== '', function ($q) use ($search): void {
            $q->where('nama_departemen', 'like', "%{$search}%");
        })
            ->orderBy('nama_departemen')
            ->paginate(10)
            ->withQueryString();

        return view('admin.departemen.index', compact('items', 'search'));
    }

    public function create(): View
    {
        return view('admin.departemen.create');
    }

    public function store(Request $request): RedirectResponse
    {
        $validated = $request->validate([
            'nama_departemen' => ['required', 'string', 'max:100', 'unique:departemen,nama_departemen'],
        ]);

        Departemen::create($validated);

        return redirect()->route('admin.departemen.index')->with('success', 'Departemen berhasil ditambahkan.');
    }

    public function edit(Departemen $departemen): View
    {
        return view('admin.departemen.edit', compact('departemen'));
    }

    public function update(Request $request, Departemen $departemen): RedirectResponse
    {
        $validated = $request->validate([
            'nama_departemen' => ['required', 'string', 'max:100', 'unique:departemen,nama_departemen,' . $departemen->id_departemen . ',id_departemen'],
        ]);

        $departemen->update($validated);

        return redirect()->route('admin.departemen.index')->with('success', 'Departemen berhasil diperbarui.');
    }

    public function destroy(Departemen $departemen): RedirectResponse
    {
        $departemen->delete();

        return redirect()->route('admin.departemen.index')->with('success', 'Departemen berhasil dihapus.');
    }
}
