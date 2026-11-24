<?php

namespace App\Services;

use App\Exceptions\DomainException;
use App\Http\Resources\LeaveResource;
use App\Models\Absensi;
use App\Models\Karyawan;
use App\Models\PengajuanIzin;
use Carbon\Carbon;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;
use Throwable;

class LeaveService
{
    public const TIMEZONE = 'Asia/Jakarta';

    /**
     * Daftar pengajuan izin milik karyawan sendiri (GET /api/v1/leaves?status=).
     *
     * @return list<array<string, mixed>>
     */
    public function listLeaves(Karyawan $karyawan, ?string $status = null): array
    {
        $query = PengajuanIzin::with('karyawan')
            ->where('id_karyawan', $karyawan->id_karyawan)
            ->orderByDesc('tanggal_pengajuan')
            ->orderByDesc('id_izin');

        if ($status !== null && $status !== '') {
            $query->where('status', $status);
        }

        return $query->get()
            ->map(static fn (PengajuanIzin $izin): array => (new LeaveResource($izin))->resolve())
            ->values()
            ->all();
    }

    /**
     * Ajukan izin/sakit/cuti baru (POST /api/v1/leaves).
     *
     * @param  array{jenis: string, tanggal_mulai: string, tanggal_selesai: string, alasan: string}  $data
     * @return array<string, mixed>
     *
     * @throws DomainException
     */
    public function createLeave(Karyawan $karyawan, array $data, ?UploadedFile $lampiran = null): array
    {
        $mulai = $data['tanggal_mulai'];
        $selesai = $data['tanggal_selesai'];

        $overlapping = PengajuanIzin::where('id_karyawan', $karyawan->id_karyawan)
            ->whereIn('status', [PengajuanIzin::STATUS_MENUNGGU, PengajuanIzin::STATUS_DISETUJUI])
            ->whereDate('tanggal_mulai', '<=', $selesai)
            ->whereDate('tanggal_selesai', '>=', $mulai)
            ->exists();

        if ($overlapping) {
            throw new DomainException(
                'Tanggal pengajuan tumpang tindih dengan pengajuan lain yang masih menunggu atau sudah disetujui.',
                'VALIDATION_ERROR',
                422,
                ['tanggal_mulai' => ['Rentang tanggal tumpang tindih dengan pengajuan sebelumnya.']]
            );
        }

        $diskName = (string) config('face.storage_disk', 'private');
        $storedPath = null;

        if ($lampiran !== null) {
            $storedPath = $lampiran->store("leaves/{$karyawan->id_karyawan}", $diskName);
            if ($storedPath === false) {
                throw new DomainException(
                    'Gagal menyimpan berkas lampiran.',
                    'SERVER_ERROR',
                    500
                );
            }
        }

        try {
            $izin = PengajuanIzin::create([
                'id_karyawan'       => $karyawan->id_karyawan,
                'id_penyetuju'      => null,
                'jenis'             => $data['jenis'],
                'tanggal_mulai'     => $mulai,
                'tanggal_selesai'   => $selesai,
                'alasan'            => $data['alasan'],
                'lampiran'          => $storedPath,
                'status'            => PengajuanIzin::STATUS_MENUNGGU,
                'tanggal_pengajuan' => Carbon::now(self::TIMEZONE),
            ]);
        } catch (Throwable $e) {
            if ($storedPath !== null) {
                Storage::disk($diskName)->delete($storedPath);
            }
            throw $e;
        }

        $izin->setRelation('karyawan', $karyawan);

        return (new LeaveResource($izin))->resolve();
    }

    /**
     * Daftar pengajuan izin bawahan langsung (GET /api/v1/approvals?status=menunggu).
     *
     * @return list<array<string, mixed>>
     */
    public function listApprovals(Karyawan $atasan, ?string $status = PengajuanIzin::STATUS_MENUNGGU): array
    {
        $query = PengajuanIzin::with('karyawan')
            ->whereHas('karyawan', static function ($q) use ($atasan): void {
                $q->where('id_atasan', $atasan->id_karyawan);
            })
            ->orderByDesc('tanggal_pengajuan')
            ->orderByDesc('id_izin');

        if ($status !== null && $status !== '') {
            $query->where('status', $status);
        }

        return $query->get()
            ->map(static fn (PengajuanIzin $izin): array => (new LeaveResource($izin))->resolve())
            ->values()
            ->all();
    }

    /**
     * Setujui pengajuan izin dan catat status izin/sakit/cuti ke tabel absensi dalam satu transaksi DB.
     *
     * @return array<string, mixed>
     *
     * @throws DomainException
     */
    public function approve(Karyawan $atasan, int $idIzin): array
    {
        $izin = PengajuanIzin::with('karyawan')->find($idIzin);
        $this->guardApprovalAction($atasan, $izin);

        DB::transaction(function () use ($atasan, $izin): void {
            $izin->update([
                'status'       => PengajuanIzin::STATUS_DISETUJUI,
                'id_penyetuju' => $atasan->id_karyawan,
            ]);

            $start = Carbon::parse($izin->tanggal_mulai, self::TIMEZONE)->startOfDay();
            $end = Carbon::parse($izin->tanggal_selesai, self::TIMEZONE)->startOfDay();

            for ($date = $start->copy(); $date->lte($end); $date->addDay()) {
                $dateStr = $date->toDateString();

                $existing = Absensi::where('id_karyawan', $izin->id_karyawan)
                    ->whereDate('tanggal', $dateStr)
                    ->first();

                if ($existing !== null) {
                    $existing->update([
                        'status'     => $izin->jenis,
                        'keterangan' => $izin->alasan,
                    ]);
                } else {
                    Absensi::create([
                        'id_karyawan' => $izin->id_karyawan,
                        'tanggal'     => $dateStr,
                        'status'      => $izin->jenis,
                        'keterangan'  => $izin->alasan,
                    ]);
                }
            }
        });

        return (new LeaveResource($izin->fresh(['karyawan'])))->resolve();
    }

    /**
     * Tolak pengajuan izin oleh atasan langsung.
     *
     * @return array<string, mixed>
     *
     * @throws DomainException
     */
    public function reject(Karyawan $atasan, int $idIzin): array
    {
        $izin = PengajuanIzin::with('karyawan')->find($idIzin);
        $this->guardApprovalAction($atasan, $izin);

        $izin->update([
            'status'       => PengajuanIzin::STATUS_DITOLAK,
            'id_penyetuju' => $atasan->id_karyawan,
        ]);

        return (new LeaveResource($izin->fresh(['karyawan'])))->resolve();
    }

    /**
     * Rekap kehadiran bawahan langsung pada rentang tanggal (GET /api/v1/team/recap).
     *
     * @return array{items: list<array<string, mixed>>}
     */
    public function getTeamRecap(Karyawan $atasan, string $from, string $to): array
    {
        $subordinates = Karyawan::where('id_atasan', $atasan->id_karyawan)
            ->orderBy('nama')
            ->get();

        $subIds = $subordinates->pluck('id_karyawan')->all();

        $absensiGrouped = empty($subIds)
            ? collect()
            : Absensi::whereIn('id_karyawan', $subIds)
                ->whereDate('tanggal', '>=', $from)
                ->whereDate('tanggal', '<=', $to)
                ->get()
                ->groupBy('id_karyawan');

        $items = $subordinates->map(static function (Karyawan $sub) use ($absensiGrouped): array {
            $counts = [
                Absensi::STATUS_HADIR     => 0,
                Absensi::STATUS_TERLAMBAT => 0,
                Absensi::STATUS_IZIN      => 0,
                Absensi::STATUS_SAKIT     => 0,
                Absensi::STATUS_CUTI      => 0,
                Absensi::STATUS_ALPA      => 0,
            ];

            foreach ($absensiGrouped->get($sub->id_karyawan, collect()) as $row) {
                if (array_key_exists($row->status, $counts)) {
                    $counts[$row->status]++;
                }
            }

            return array_merge([
                'id_karyawan' => (int) $sub->id_karyawan,
                'nama'        => (string) $sub->nama,
            ], $counts);
        })->values()->all();

        return ['items' => $items];
    }

    /**
     * @throws DomainException
     */
    private function guardApprovalAction(Karyawan $atasan, ?PengajuanIzin $izin): void
    {
        if ($izin === null) {
            throw new DomainException(
                'Pengajuan izin tidak ditemukan.',
                'NOT_FOUND',
                404
            );
        }

        if ((int) $izin->karyawan?->id_atasan !== (int) $atasan->id_karyawan) {
            throw new DomainException(
                'Anda bukan atasan langsung pemohon.',
                'NOT_APPROVER',
                403
            );
        }

        if ($izin->status !== PengajuanIzin::STATUS_MENUNGGU) {
            throw new DomainException(
                'Pengajuan izin sudah diproses sebelumnya.',
                'VALIDATION_ERROR',
                409
            );
        }
    }
}
