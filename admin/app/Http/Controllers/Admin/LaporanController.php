<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Models\Absensi;
use App\Models\Departemen;
use App\Models\Karyawan;
use Carbon\Carbon;
use Illuminate\Http\Request;
use Illuminate\Support\Collection;
use Illuminate\View\View;
use Symfony\Component\HttpFoundation\StreamedResponse;

class LaporanController extends Controller
{
    public function index(Request $request): View
    {
        [$from, $to, $idDepartemen, $idKaryawan, $rows] = $this->buildRecap($request);

        return view('admin.laporan.index', [
            'from'           => $from,
            'to'             => $to,
            'idDepartemen'   => $idDepartemen,
            'idKaryawan'     => $idKaryawan,
            'rows'           => $rows,
            'departemenList' => Departemen::orderBy('nama_departemen')->get(),
            'karyawanList'   => Karyawan::orderBy('nama')->get(),
        ]);
    }

    public function exportCsv(Request $request): StreamedResponse
    {
        [$from, $to, , , $rows] = $this->buildRecap($request);

        $filename = "rekap-absensi-{$from}-sd-{$to}.csv";

        return response()->streamDownload(function () use ($rows): void {
            $handle = fopen('php://output', 'w');
            fputcsv($handle, ['NIK', 'Nama', 'Departemen', 'Hadir', 'Terlambat', 'Izin', 'Sakit', 'Cuti', 'Alpa']);

            foreach ($rows as $row) {
                fputcsv($handle, [
                    $row['nik'],
                    $row['nama'],
                    $row['departemen'],
                    $row['hadir'],
                    $row['terlambat'],
                    $row['izin'],
                    $row['sakit'],
                    $row['cuti'],
                    $row['alpa'],
                ]);
            }

            fclose($handle);
        }, $filename, [
            'Content-Type' => 'text/csv; charset=UTF-8',
        ]);
    }

    /**
     * @return array{0: string, 1: string, 2: int|null, 3: int|null, 4: Collection<int, array<string, mixed>>}
     */
    private function buildRecap(Request $request): array
    {
        $now = Carbon::now('Asia/Jakarta');
        $from = (string) $request->query('from', $now->copy()->startOfMonth()->toDateString());
        $to = (string) $request->query('to', $now->copy()->endOfMonth()->toDateString());
        $idDepartemen = $request->filled('id_departemen') ? (int) $request->query('id_departemen') : null;
        $idKaryawan = $request->filled('id_karyawan') ? (int) $request->query('id_karyawan') : null;

        $karyawanList = Karyawan::with('departemen')
            ->when($idDepartemen !== null, fn ($q) => $q->where('id_departemen', $idDepartemen))
            ->when($idKaryawan !== null, fn ($q) => $q->where('id_karyawan', $idKaryawan))
            ->orderBy('nama')
            ->get();

        $ids = $karyawanList->pluck('id_karyawan')->all();
        $absensiGrouped = empty($ids)
            ? collect()
            : Absensi::whereIn('id_karyawan', $ids)
                ->whereDate('tanggal', '>=', $from)
                ->whereDate('tanggal', '<=', $to)
                ->get()
                ->groupBy('id_karyawan');

        $rows = $karyawanList->map(static function (Karyawan $k) use ($absensiGrouped): array {
            $counts = [
                Absensi::STATUS_HADIR     => 0,
                Absensi::STATUS_TERLAMBAT => 0,
                Absensi::STATUS_IZIN      => 0,
                Absensi::STATUS_SAKIT     => 0,
                Absensi::STATUS_CUTI      => 0,
                Absensi::STATUS_ALPA      => 0,
            ];

            foreach ($absensiGrouped->get($k->id_karyawan, collect()) as $row) {
                if (array_key_exists($row->status, $counts)) {
                    $counts[$row->status]++;
                }
            }

            return array_merge([
                'id_karyawan' => $k->id_karyawan,
                'nik'         => $k->nik,
                'nama'        => $k->nama,
                'departemen'  => $k->departemen?->nama_departemen ?? '-',
            ], $counts);
        });

        return [$from, $to, $idDepartemen, $idKaryawan, $rows];
    }
}
