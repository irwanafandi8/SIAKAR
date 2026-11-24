<?php

namespace App\Services;

use App\Exceptions\DomainException;
use App\Http\Resources\AttendanceResource;
use App\Models\Absensi;
use App\Models\DataWajah;
use App\Models\HariLibur;
use App\Models\JadwalKaryawan;
use App\Models\Karyawan;
use App\Models\LokasiKantor;
use Carbon\Carbon;
use Carbon\CarbonInterface;
use Illuminate\Database\QueryException;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Storage;
use Throwable;

class AttendanceService
{
    public const TIMEZONE = 'Asia/Jakarta';

    public function __construct(
        private readonly GeofenceService $geofenceService,
        private readonly FaceMatchService $faceMatchService
    ) {}

    /**
     * Informasi absensi hari ini untuk layar Beranda/Absen (GET /api/v1/attendance/today).
     *
     * @return array<string, mixed>
     */
    public function getTodayInfo(Karyawan $karyawan): array
    {
        $today = Carbon::now(self::TIMEZONE)->toDateString();

        $isHoliday = HariLibur::whereDate('tanggal', $today)->exists();

        $jadwal = JadwalKaryawan::with('shift')
            ->where('id_karyawan', $karyawan->id_karyawan)
            ->whereDate('tanggal', $today)
            ->first();

        $shift = $jadwal?->shift;
        $hasSchedule = $shift !== null;

        $absensi = Absensi::with('lokasi')
            ->where('id_karyawan', $karyawan->id_karyawan)
            ->whereDate('tanggal', $today)
            ->first();

        $locations = LokasiKantor::orderBy('id_lokasi')
            ->get()
            ->map(static fn (LokasiKantor $lokasi): array => [
                'id_lokasi'    => (int) $lokasi->id_lokasi,
                'nama'         => $lokasi->nama_lokasi,
                'latitude'     => (float) $lokasi->latitude,
                'longitude'    => (float) $lokasi->longitude,
                'radius_meter' => (int) $lokasi->radius_meter,
            ])
            ->values()
            ->all();

        return [
            'tanggal'      => $today,
            'has_schedule' => $hasSchedule,
            'is_holiday'   => $isHoliday,
            'shift'        => $shift ? [
                'nama'            => $shift->nama_shift,
                'jam_masuk'       => $this->normalizeTimeString($shift->jam_masuk),
                'jam_pulang'      => $this->normalizeTimeString($shift->jam_pulang),
                'toleransi_menit' => (int) $shift->toleransi_menit,
            ] : null,
            'attendance'   => $absensi ? (new AttendanceResource($absensi))->resolve() : null,
            'locations'    => $locations,
        ];
    }

    /**
     * Hitung status kehadiran masuk dari waktu server terhadap jam_masuk shift + toleransi_menit.
     * Terlambat bila waktu_absen > shift.jam_masuk + toleransi_menit; selain itu hadir.
     */
    public function determineCheckInStatus(
        string $jamMasukShift,
        int $toleransiMenit,
        CarbonInterface|string $waktuAbsen
    ): string {
        if ($waktuAbsen instanceof CarbonInterface) {
            $wib = Carbon::instance($waktuAbsen)->timezone(self::TIMEZONE);
            $dateStr = $wib->toDateString();
            $actualTimeStr = $wib->format('H:i:s');
        } else {
            $dateStr = '2026-01-01';
            $actualTimeStr = $this->normalizeTimeString($waktuAbsen);
        }

        $shiftTimeStr = $this->normalizeTimeString($jamMasukShift);

        $deadline = Carbon::createFromFormat('Y-m-d H:i:s', "{$dateStr} {$shiftTimeStr}", self::TIMEZONE)
            ->addMinutes($toleransiMenit);
        $actual = Carbon::createFromFormat('Y-m-d H:i:s', "{$dateStr} {$actualTimeStr}", self::TIMEZONE);

        return $actual->gt($deadline)
            ? Absensi::STATUS_TERLAMBAT
            : Absensi::STATUS_HADIR;
    }

    /**
     * Proses absen masuk (POST /api/v1/attendance/check-in) sesuai urutan API.md §3.3.
     *
     * @return array<string, mixed>
     *
     * @throws DomainException
     */
    public function checkIn(
        Karyawan $karyawan,
        string $rawEmbedding,
        float $latitude,
        float $longitude,
        bool $livenessPassed,
        UploadedFile $photo
    ): array {
        $now = Carbon::now(self::TIMEZONE);
        $today = $now->toDateString();

        try {
            // Langkah 3: Bentuk embedding & liveness_passed
            $probeEmbedding = $this->decodeAndValidateEmbedding($rawEmbedding);
            $this->ensureLivenessPassed($livenessPassed);

            // Langkah 4: Wajah terdaftar
            $activeFace = $this->requireActiveFace($karyawan);

            // Langkah 5: Hari libur -> jadwal
            $jadwal = $this->requireWorkdaySchedule($karyawan, $today);

            // Langkah 6: Status absensi hari ini (check-in -> ALREADY_CHECKED_IN)
            $existing = Absensi::where('id_karyawan', $karyawan->id_karyawan)
                ->whereDate('tanggal', $today)
                ->first();

            if ($existing !== null) {
                throw new DomainException(
                    'Anda sudah memiliki catatan absensi pada hari ini.',
                    'ALREADY_CHECKED_IN',
                    409
                );
            }

            // Langkah 7: Lokasi (Haversine ke semua lokasi_kantor)
            $geofence = $this->geofenceService->validateGeofence($latitude, $longitude);

            // Langkah 8: Kecocokan wajah (cosine >= face.threshold)
            $similarity = $this->verifyFaceMatch($probeEmbedding, $activeFace);
        } catch (DomainException $e) {
            $this->logRejectedAttempt($karyawan, 'check_in', $e);
            throw $e;
        }

        // Langkah 9: Hitung status Hadir/Terlambat dari waktu server dan simpan absensi + foto privat
        $status = $this->determineCheckInStatus(
            (string) $jadwal->shift->jam_masuk,
            (int) $jadwal->shift->toleransi_menit,
            $now
        );

        $diskName = (string) config('face.storage_disk', 'private');
        $storedPhotoPath = $this->storeEvidencePhoto($photo, $karyawan->id_karyawan, $today, 'in', $diskName);

        try {
            $absensi = DB::transaction(function () use (
                $karyawan,
                $jadwal,
                $geofence,
                $today,
                $now,
                $latitude,
                $longitude,
                $storedPhotoPath,
                $similarity,
                $status
            ): Absensi {
                $alreadyExists = Absensi::where('id_karyawan', $karyawan->id_karyawan)
                    ->whereDate('tanggal', $today)
                    ->lockForUpdate()
                    ->exists();

                if ($alreadyExists) {
                    throw new DomainException(
                        'Anda sudah memiliki catatan absensi pada hari ini.',
                        'ALREADY_CHECKED_IN',
                        409
                    );
                }

                return Absensi::create([
                    'id_karyawan' => $karyawan->id_karyawan,
                    'id_shift'    => $jadwal->id_shift,
                    'id_lokasi'   => $geofence['location']->id_lokasi,
                    'tanggal'     => $today,
                    'jam_masuk'   => $now->format('H:i:s'),
                    'lat_masuk'   => $latitude,
                    'long_masuk'  => $longitude,
                    'foto_masuk'  => $storedPhotoPath,
                    'skor_wajah'  => round($similarity, 4),
                    'status'      => $status,
                ]);
            });
        } catch (QueryException $e) {
            Storage::disk($diskName)->delete($storedPhotoPath);
            $domainException = new DomainException(
                'Anda sudah memiliki catatan absensi pada hari ini.',
                'ALREADY_CHECKED_IN',
                409
            );
            $this->logRejectedAttempt($karyawan, 'check_in', $domainException);
            throw $domainException;
        } catch (Throwable $e) {
            Storage::disk($diskName)->delete($storedPhotoPath);
            if ($e instanceof DomainException) {
                $this->logRejectedAttempt($karyawan, 'check_in', $e);
            }
            throw $e;
        }

        $absensi->setRelation('lokasi', $geofence['location']);

        return [
            'attendance'     => (new AttendanceResource($absensi))->resolve(),
            'similarity'     => round($similarity, 4),
            'distance_meter' => round($geofence['distance_meter'], 2),
            'status'         => $absensi->status,
        ];
    }

    /**
     * Proses absen pulang (POST /api/v1/attendance/check-out) sesuai urutan API.md §3.3.
     *
     * @return array<string, mixed>
     *
     * @throws DomainException
     */
    public function checkOut(
        Karyawan $karyawan,
        string $rawEmbedding,
        float $latitude,
        float $longitude,
        bool $livenessPassed,
        UploadedFile $photo
    ): array {
        $now = Carbon::now(self::TIMEZONE);
        $today = $now->toDateString();

        try {
            // Langkah 3: Bentuk embedding & liveness_passed
            $probeEmbedding = $this->decodeAndValidateEmbedding($rawEmbedding);
            $this->ensureLivenessPassed($livenessPassed);

            // Langkah 4: Wajah terdaftar
            $activeFace = $this->requireActiveFace($karyawan);

            // Langkah 5: Hari libur -> jadwal
            $this->requireWorkdaySchedule($karyawan, $today);

            // Langkah 6: Status absensi hari ini (check-out -> NOT_CHECKED_IN / ALREADY_CHECKED_OUT)
            $existing = Absensi::where('id_karyawan', $karyawan->id_karyawan)
                ->whereDate('tanggal', $today)
                ->first();

            if ($existing === null || $existing->jam_masuk === null) {
                throw new DomainException(
                    'Anda belum melakukan absen masuk hari ini.',
                    'NOT_CHECKED_IN',
                    409
                );
            }

            if ($existing->jam_pulang !== null) {
                throw new DomainException(
                    'Anda sudah melakukan absen pulang hari ini.',
                    'ALREADY_CHECKED_OUT',
                    409
                );
            }

            // Langkah 7: Lokasi (Haversine ke semua lokasi_kantor)
            $geofence = $this->geofenceService->validateGeofence($latitude, $longitude);

            // Langkah 8: Kecocokan wajah (cosine >= face.threshold)
            $similarity = $this->verifyFaceMatch($probeEmbedding, $activeFace);
        } catch (DomainException $e) {
            $this->logRejectedAttempt($karyawan, 'check_out', $e);
            throw $e;
        }

        // Langkah 9: Simpan pembaruan baris absensi hari ini + foto pulang privat
        $diskName = (string) config('face.storage_disk', 'private');
        $storedPhotoPath = $this->storeEvidencePhoto($photo, $karyawan->id_karyawan, $today, 'out', $diskName);

        try {
            $absensi = DB::transaction(function () use (
                $karyawan,
                $today,
                $now,
                $latitude,
                $longitude,
                $storedPhotoPath,
                $geofence,
                $similarity
            ): Absensi {
                $locked = Absensi::where('id_karyawan', $karyawan->id_karyawan)
                    ->whereDate('tanggal', $today)
                    ->lockForUpdate()
                    ->first();

                if ($locked === null || $locked->jam_masuk === null) {
                    throw new DomainException(
                        'Anda belum melakukan absen masuk hari ini.',
                        'NOT_CHECKED_IN',
                        409
                    );
                }

                if ($locked->jam_pulang !== null) {
                    throw new DomainException(
                        'Anda sudah melakukan absen pulang hari ini.',
                        'ALREADY_CHECKED_OUT',
                        409
                    );
                }

                $locked->update([
                    'id_lokasi'   => $locked->id_lokasi ?? $geofence['location']->id_lokasi,
                    'jam_pulang'  => $now->format('H:i:s'),
                    'lat_pulang'  => $latitude,
                    'long_pulang' => $longitude,
                    'foto_pulang' => $storedPhotoPath,
                    'skor_wajah'  => $locked->skor_wajah ?? round($similarity, 4),
                ]);

                return $locked->load('lokasi');
            });
        } catch (Throwable $e) {
            Storage::disk($diskName)->delete($storedPhotoPath);
            if ($e instanceof DomainException) {
                $this->logRejectedAttempt($karyawan, 'check_out', $e);
            }
            throw $e;
        }

        return [
            'attendance'     => (new AttendanceResource($absensi))->resolve(),
            'similarity'     => round($similarity, 4),
            'distance_meter' => round($geofence['distance_meter'], 2),
            'status'         => $absensi->status,
        ];
    }

    /**
     * Riwayat absensi bulanan beserta ringkasan per status (GET /api/v1/attendance/history?month=YYYY-MM).
     *
     * @return array<string, mixed>
     */
    public function getHistory(Karyawan $karyawan, ?string $month = null): array
    {
        $activeMonth = ($month !== null && $month !== '')
            ? $month
            : Carbon::now(self::TIMEZONE)->format('Y-m');

        $startOfMonth = Carbon::createFromFormat('Y-m-d', "{$activeMonth}-01", self::TIMEZONE)->startOfMonth();
        $endOfMonth = $startOfMonth->copy()->endOfMonth();

        $records = Absensi::with('lokasi')
            ->where('id_karyawan', $karyawan->id_karyawan)
            ->whereDate('tanggal', '>=', $startOfMonth->toDateString())
            ->whereDate('tanggal', '<=', $endOfMonth->toDateString())
            ->orderByDesc('tanggal')
            ->get();

        $summary = [
            Absensi::STATUS_HADIR     => 0,
            Absensi::STATUS_TERLAMBAT => 0,
            Absensi::STATUS_IZIN      => 0,
            Absensi::STATUS_SAKIT     => 0,
            Absensi::STATUS_CUTI      => 0,
            Absensi::STATUS_ALPA      => 0,
        ];

        foreach ($records as $record) {
            if (array_key_exists($record->status, $summary)) {
                $summary[$record->status]++;
            }
        }

        $items = $records
            ->map(static fn (Absensi $item): array => (new AttendanceResource($item))->resolve())
            ->values()
            ->all();

        return [
            'month'   => $activeMonth,
            'items'   => $items,
            'summary' => $summary,
        ];
    }

    /**
     * @return list<float>
     *
     * @throws DomainException
     */
    private function decodeAndValidateEmbedding(string $rawEmbedding): array
    {
        $decoded = json_decode($rawEmbedding, true);
        if (json_last_error() !== JSON_ERROR_NONE) {
            throw new DomainException(
                'Format JSON embedding wajah tidak valid.',
                'INVALID_EMBEDDING',
                422
            );
        }

        return $this->faceMatchService->validateEmbedding($decoded);
    }

    /**
     * @throws DomainException
     */
    private function ensureLivenessPassed(bool $livenessPassed): void
    {
        if (!$livenessPassed) {
            throw new DomainException(
                'Verifikasi keaktifan wajah (liveness) gagal.',
                'LIVENESS_FAILED',
                422
            );
        }
    }

    /**
     * @throws DomainException
     */
    private function requireActiveFace(Karyawan $karyawan): DataWajah
    {
        $activeFace = DataWajah::where('id_karyawan', $karyawan->id_karyawan)
            ->where('aktif', true)
            ->latest('id_wajah')
            ->first();

        if (!$activeFace) {
            throw new DomainException(
                'Wajah belum didaftarkan. Silakan registrasi wajah terlebih dahulu.',
                'FACE_NOT_ENROLLED',
                422
            );
        }

        return $activeFace;
    }

    /**
     * Periksa hari libur terlebih dahulu, lalu jadwal kerja karyawan pada tanggal tersebut.
     *
     * @throws DomainException
     */
    private function requireWorkdaySchedule(Karyawan $karyawan, string $date): JadwalKaryawan
    {
        $hariLibur = HariLibur::whereDate('tanggal', $date)->first();
        if ($hariLibur !== null) {
            $suffix = $hariLibur->keterangan ? " ({$hariLibur->keterangan})" : '';
            throw new DomainException(
                "Hari ini merupakan hari libur{$suffix}.",
                'HOLIDAY',
                422
            );
        }

        $jadwal = JadwalKaryawan::with('shift')
            ->where('id_karyawan', $karyawan->id_karyawan)
            ->whereDate('tanggal', $date)
            ->first();

        if ($jadwal === null || $jadwal->shift === null) {
            throw new DomainException(
                'Tidak ada jadwal kerja untuk Anda pada hari ini.',
                'NO_SCHEDULE',
                422
            );
        }

        return $jadwal;
    }

    /**
     * @param  list<float>  $probeEmbedding
     *
     * @throws DomainException
     */
    private function verifyFaceMatch(array $probeEmbedding, DataWajah $activeFace): float
    {
        $enrolledEmbedding = $this->faceMatchService->decryptEmbedding($activeFace->embedding);
        $matchResult = $this->faceMatchService->isMatch($probeEmbedding, $enrolledEmbedding);

        if (!$matchResult['matched']) {
            throw new DomainException(
                'Wajah tidak cocok dengan data yang terdaftar.',
                'FACE_MISMATCH',
                422,
                null,
                ['similarity' => round($matchResult['similarity'], 4)]
            );
        }

        return $matchResult['similarity'];
    }

    /**
     * @throws DomainException
     */
    private function storeEvidencePhoto(
        UploadedFile $photo,
        int $idKaryawan,
        string $date,
        string $type,
        string $diskName
    ): string {
        $storedPath = $photo->store("attendance/{$idKaryawan}/{$date}/{$type}", $diskName);

        if ($storedPath === false) {
            throw new DomainException(
                'Gagal menyimpan foto bukti absensi.',
                'SERVER_ERROR',
                500
            );
        }

        return $storedPath;
    }

    /**
     * Catat percobaan absensi yang gagal tanpa menyertakan embedding mentah.
     */
    private function logRejectedAttempt(Karyawan $karyawan, string $action, DomainException $exception): void
    {
        Log::warning('Percobaan absensi ditolak.', [
            'id_karyawan' => $karyawan->id_karyawan,
            'action'      => $action,
            'code'        => $exception->getErrorCode(),
            'status'      => $exception->getStatusCode(),
            'meta'        => $exception->getExtraData(),
        ]);
    }

    private function normalizeTimeString(string $time): string
    {
        $trimmed = trim($time);

        return strlen($trimmed) === 5 ? "{$trimmed}:00" : substr($trimmed, 0, 8);
    }
}
