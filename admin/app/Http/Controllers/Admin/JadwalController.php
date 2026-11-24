<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Models\JadwalKaryawan;
use App\Models\Karyawan;
use App\Models\Shift;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;
use Illuminate\View\View;

class JadwalController extends Controller
{
    public function index(Request $request): View
    {
        $search = trim((string) $request->query('search', ''));
        $items = JadwalKaryawan::with(['karyawan', 'shift'])
            ->when($search !== '', function ($q) use ($search): void {
                $q->whereHas('karyawan', fn ($k) => $k->where('nama', 'like', "%{$search}%")->orWhere('nik', 'like', "%{$search}%"));
            })
            ->orderByDesc('tanggal')
            ->paginate(10)
            ->withQueryString();

        return view('admin.jadwal.index', compact('items', 'search'));
    }

    public function create(): View
    {
        return view('admin.jadwal.create', [
            'karyawanList' => Karyawan::where('status_aktif', true)->orderBy('nama')->get(),
            'shiftList'    => Shift::orderBy('nama_shift')->get(),
        ]);
    }

    public function store(Request $request): RedirectResponse
    {
        $validated = $request->validate([
            'id_karyawan' => ['required', 'exists:karyawan,id_karyawan'],
            'id_shift'    => ['required', 'exists:shift,id_shift'],
            'tanggal'     => [
                'required',
                'date_format:Y-m-d',
                Rule::unique('jadwal_karyawan', 'tanggal')->where(
                    fn ($q) => $q->where('id_karyawan', $request->input('id_karyawan'))
                ),
            ],
        ]);

        JadwalKaryawan::create($validated);

        return redirect()->route('admin.jadwal.index')->with('success', 'Jadwal karyawan berhasil ditambahkan.');
    }

    public function edit(JadwalKaryawan $jadwal): View
    {
        return view('admin.jadwal.edit', [
            'jadwal'       => $jadwal,
            'karyawanList' => Karyawan::where('status_aktif', true)->orderBy('nama')->get(),
            'shiftList'    => Shift::orderBy('nama_shift')->get(),
        ]);
    }

    public function update(Request $request, JadwalKaryawan $jadwal): RedirectResponse
    {
        $validated = $request->validate([
            'id_karyawan' => ['required', 'exists:karyawan,id_karyawan'],
            'id_shift'    => ['required', 'exists:shift,id_shift'],
            'tanggal'     => [
                'required',
                'date_format:Y-m-d',
                Rule::unique('jadwal_karyawan', 'tanggal')
                    ->ignore($jadwal->id_jadwal, 'id_jadwal')
                    ->where(fn ($q) => $q->where('id_karyawan', $request->input('id_karyawan'))),
            ],
        ]);

        $jadwal->update($validated);

        return redirect()->route('admin.jadwal.index')->with('success', 'Jadwal karyawan berhasil diperbarui.');
    }

    public function destroy(JadwalKaryawan $jadwal): RedirectResponse
    {
        $jadwal->delete();

        return redirect()->route('admin.jadwal.index')->with('success', 'Jadwal karyawan berhasil dihapus.');
    }
}
