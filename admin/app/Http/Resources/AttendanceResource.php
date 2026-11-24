<?php

namespace App\Http\Resources;

use App\Models\Absensi;
use Carbon\CarbonInterface;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * @mixin Absensi
 */
class AttendanceResource extends JsonResource
{
    /**
     * Transformasikan model Absensi sesuai tipe `attendance` di API.md §2.
     *
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        $tanggal = $this->tanggal instanceof CarbonInterface
            ? $this->tanggal->format('Y-m-d')
            : substr((string) $this->tanggal, 0, 10);

        return [
            'id_absensi' => (int) $this->id_absensi,
            'tanggal'    => $tanggal,
            'jam_masuk'  => $this->normalizeTime($this->jam_masuk),
            'jam_pulang' => $this->normalizeTime($this->jam_pulang),
            'status'     => (string) $this->status,
            'skor_wajah' => $this->skor_wajah !== null ? round((float) $this->skor_wajah, 4) : null,
            'lokasi'     => $this->lokasi?->nama_lokasi,
            'keterangan' => $this->keterangan,
        ];
    }

    private function normalizeTime(mixed $value): ?string
    {
        if ($value === null || $value === '') {
            return null;
        }

        $str = trim((string) $value);

        return strlen($str) === 5 ? "{$str}:00" : substr($str, 0, 8);
    }
}
