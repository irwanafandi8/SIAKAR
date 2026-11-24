<?php

namespace App\Http\Resources;

use App\Models\PengajuanIzin;
use Carbon\Carbon;
use Carbon\CarbonInterface;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * @mixin PengajuanIzin
 */
class LeaveResource extends JsonResource
{
    /**
     * Transformasikan PengajuanIzin sesuai tipe `leave` di API.md §2.
     *
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        $mulai = $this->tanggal_mulai instanceof CarbonInterface
            ? $this->tanggal_mulai->format('Y-m-d')
            : substr((string) $this->tanggal_mulai, 0, 10);

        $selesai = $this->tanggal_selesai instanceof CarbonInterface
            ? $this->tanggal_selesai->format('Y-m-d')
            : substr((string) $this->tanggal_selesai, 0, 10);

        $pengajuan = $this->tanggal_pengajuan
            ? Carbon::parse($this->tanggal_pengajuan)->timezone('Asia/Jakarta')->toIso8601String()
            : null;

        return [
            'id_izin'           => (int) $this->id_izin,
            'jenis'             => (string) $this->jenis,
            'tanggal_mulai'     => $mulai,
            'tanggal_selesai'   => $selesai,
            'alasan'            => (string) $this->alasan,
            'lampiran_url'      => $this->lampiran ? '/api/v1/leaves/' . $this->id_izin . '/attachment' : null,
            'status'            => (string) $this->status,
            'pemohon'           => [
                'id_karyawan' => (int) ($this->karyawan?->id_karyawan ?? $this->id_karyawan),
                'nama'        => (string) ($this->karyawan?->nama ?? ''),
            ],
            'tanggal_pengajuan' => $pengajuan,
        ];
    }
}
