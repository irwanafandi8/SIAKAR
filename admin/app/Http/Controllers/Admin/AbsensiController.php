<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Models\Absensi;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Storage;
use Illuminate\Validation\Rule;
use Illuminate\View\View;
use Symfony\Component\HttpFoundation\StreamedResponse;

class AbsensiController extends Controller
{
    public function index(Request $request): View
    {
        $search = trim((string) $request->query('search', ''));
        $tanggal = trim((string) $request->query('tanggal', ''));

        $items = Absensi::with(['karyawan', 'shift', 'lokasi'])
            ->when($search !== '', function ($q) use ($search): void {
                $q->whereHas('karyawan', fn ($k) => $k->where('nama', 'like', "%{$search}%")->orWhere('nik', 'like', "%{$search}%"));
            })
            ->when($tanggal !== '', fn ($q) => $q->whereDate('tanggal', $tanggal))
            ->orderByDesc('tanggal')
            ->orderByDesc('id_absensi')
            ->paginate(10)
            ->withQueryString();

        return view('admin.absensi.index', compact('items', 'search', 'tanggal'));
    }

    public function edit(Absensi $absensi): View
    {
        $absensi->load(['karyawan', 'shift', 'lokasi']);

        return view('admin.absensi.edit', compact('absensi'));
    }

    public function update(Request $request, Absensi $absensi): RedirectResponse
    {
        $validated = $request->validate([
            'status'     => ['required', Rule::in([
                Absensi::STATUS_HADIR,
                Absensi::STATUS_TERLAMBAT,
                Absensi::STATUS_IZIN,
                Absensi::STATUS_SAKIT,
                Absensi::STATUS_CUTI,
                Absensi::STATUS_ALPA,
            ])],
            'keterangan' => ['required', 'string', 'min:3', 'max:500'],
        ]);

        $oldStatus = $absensi->status;
        $absensi->update([
            'status'     => $validated['status'],
            'keterangan' => $validated['keterangan'],
        ]);

        Log::info('Admin melakukan koreksi absensi.', [
            'id_absensi' => $absensi->id_absensi,
            'id_admin'   => $request->user()?->id_pengguna,
            'old_status' => $oldStatus,
            'new_status' => $validated['status'],
            'keterangan' => $validated['keterangan'],
        ]);

        return redirect()->route('admin.absensi.index')->with('success', 'Koreksi absensi berhasil disimpan.');
    }

    public function photo(Absensi $absensi, string $type): StreamedResponse
    {
        $path = match ($type) {
            'masuk'  => $absensi->foto_masuk,
            'pulang' => $absensi->foto_pulang,
            default  => null,
        };

        $diskName = (string) config('face.storage_disk', 'private');
        if (!$path || !Storage::disk($diskName)->exists($path)) {
            abort(404, 'Foto bukti tidak ditemukan.');
        }

        return Storage::disk($diskName)->response($path);
    }
}
