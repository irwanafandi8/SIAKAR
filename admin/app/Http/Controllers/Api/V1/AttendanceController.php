<?php

namespace App\Http\Controllers\Api\V1;

use App\Exceptions\DomainException;
use App\Http\Controllers\Controller;
use App\Http\Requests\AttendanceCheckRequest;
use App\Http\Requests\AttendanceHistoryRequest;
use App\Models\Karyawan;
use App\Services\AttendanceService;
use App\Support\ApiResponse;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class AttendanceController extends Controller
{
    public function __construct(
        private readonly AttendanceService $attendanceService
    ) {}

    /**
     * GET /api/v1/attendance/today
     */
    public function today(Request $request): JsonResponse
    {
        $karyawan = $this->resolveKaryawan($request);

        return ApiResponse::success(
            $this->attendanceService->getTodayInfo($karyawan)
        );
    }

    /**
     * POST /api/v1/attendance/check-in
     */
    public function checkIn(AttendanceCheckRequest $request): JsonResponse
    {
        $karyawan = $this->resolveKaryawan($request);

        $result = $this->attendanceService->checkIn(
            $karyawan,
            (string) $request->validated('embedding'),
            (float) $request->validated('latitude'),
            (float) $request->validated('longitude'),
            (bool) $request->boolean('liveness_passed'),
            $request->file('photo')
        );

        return ApiResponse::created($result, 'Absen masuk berhasil.');
    }

    /**
     * POST /api/v1/attendance/check-out
     */
    public function checkOut(AttendanceCheckRequest $request): JsonResponse
    {
        $karyawan = $this->resolveKaryawan($request);

        $result = $this->attendanceService->checkOut(
            $karyawan,
            (string) $request->validated('embedding'),
            (float) $request->validated('latitude'),
            (float) $request->validated('longitude'),
            (bool) $request->boolean('liveness_passed'),
            $request->file('photo')
        );

        return ApiResponse::created($result, 'Absen pulang berhasil.');
    }

    /**
     * GET /api/v1/attendance/history
     */
    public function history(AttendanceHistoryRequest $request): JsonResponse
    {
        $karyawan = $this->resolveKaryawan($request);

        return ApiResponse::success(
            $this->attendanceService->getHistory(
                $karyawan,
                $request->validated('month')
            )
        );
    }

    private function resolveKaryawan(Request $request): Karyawan
    {
        $karyawan = $request->user()?->karyawan;

        if (!$karyawan) {
            throw new DomainException(
                'Data profil karyawan tidak ditemukan.',
                'NOT_FOUND',
                404
            );
        }

        return $karyawan;
    }
}
