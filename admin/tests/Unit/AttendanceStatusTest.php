<?php

namespace Tests\Unit;

use App\Models\Absensi;
use App\Services\AttendanceService;
use App\Services\FaceMatchService;
use App\Services\GeofenceService;
use Carbon\Carbon;
use PHPUnit\Framework\TestCase;

class AttendanceStatusTest extends TestCase
{
    private AttendanceService $service;

    protected function setUp(): void
    {
        parent::setUp();
        $this->service = new AttendanceService(
            new GeofenceService(),
            new FaceMatchService()
        );
    }

    public function test_before_shift_start_is_hadir(): void
    {
        $status = $this->service->determineCheckInStatus('08:00:00', 10, '07:45:00');
        $this->assertSame(Absensi::STATUS_HADIR, $status);
    }

    public function test_exact_shift_start_is_hadir(): void
    {
        $status = $this->service->determineCheckInStatus('08:00:00', 10, '08:00:00');
        $this->assertSame(Absensi::STATUS_HADIR, $status);
    }

    public function test_exact_tolerance_boundary_to_the_second_is_hadir(): void
    {
        // Tepat di batas toleransi: 08:00:00 + 10 menit = 08:10:00 -> masih HADIR
        $waktuAbsen = Carbon::create(2026, 11, 24, 8, 10, 0, 'Asia/Jakarta');
        $status = $this->service->determineCheckInStatus('08:00:00', 10, $waktuAbsen);

        $this->assertSame(Absensi::STATUS_HADIR, $status);
    }

    public function test_one_second_past_tolerance_boundary_is_terlambat(): void
    {
        // Lewat 1 detik dari batas toleransi: 08:10:01 > 08:10:00 -> TERLAMBAT
        $waktuAbsen = Carbon::create(2026, 11, 24, 8, 10, 1, 'Asia/Jakarta');
        $status = $this->service->determineCheckInStatus('08:00:00', 10, $waktuAbsen);

        $this->assertSame(Absensi::STATUS_TERLAMBAT, $status);
    }

    public function test_zero_tolerance_shift_marks_one_second_late_as_terlambat(): void
    {
        $this->assertSame(
            Absensi::STATUS_HADIR,
            $this->service->determineCheckInStatus('07:00:00', 0, '07:00:00')
        );
        $this->assertSame(
            Absensi::STATUS_TERLAMBAT,
            $this->service->determineCheckInStatus('07:00:00', 0, '07:00:01')
        );
    }

    public function test_server_timezone_conversion_to_wib(): void
    {
        // 01:10:00 UTC == 08:10:00 WIB (masih hadir), 01:10:01 UTC == 08:10:01 WIB (terlambat)
        $utcOnBoundary = Carbon::create(2026, 11, 24, 1, 10, 0, 'UTC');
        $utcLate = Carbon::create(2026, 11, 24, 1, 10, 1, 'UTC');

        $this->assertSame(
            Absensi::STATUS_HADIR,
            $this->service->determineCheckInStatus('08:00:00', 10, $utcOnBoundary)
        );
        $this->assertSame(
            Absensi::STATUS_TERLAMBAT,
            $this->service->determineCheckInStatus('08:00:00', 10, $utcLate)
        );
    }
}
