<?php

namespace App\Http\Controllers\Api\V1;

use App\Exceptions\DomainException;
use App\Http\Controllers\Controller;
use App\Http\Requests\TeamRecapRequest;
use App\Models\Karyawan;
use App\Models\PengajuanIzin;
use App\Services\LeaveService;
use App\Support\ApiResponse;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class ApprovalController extends Controller
{
    public function __construct(
        private readonly LeaveService $leaveService
    ) {}

    /**
     * GET /api/v1/approvals?status=menunggu
     */
    public function index(Request $request): JsonResponse
    {
        $atasan = $this->resolveKaryawan($request);
        $status = $request->query('status', PengajuanIzin::STATUS_MENUNGGU);

        return ApiResponse::success(
            $this->leaveService->listApprovals($atasan, is_string($status) ? $status : null)
        );
    }

    /**
     * POST /api/v1/approvals/{id_izin}/approve
     */
    public function approve(Request $request, int $idIzin): JsonResponse
    {
        $atasan = $this->resolveKaryawan($request);

        return ApiResponse::success(
            $this->leaveService->approve($atasan, $idIzin),
            'Pengajuan izin disetujui.'
        );
    }

    /**
     * POST /api/v1/approvals/{id_izin}/reject
     */
    public function reject(Request $request, int $idIzin): JsonResponse
    {
        $atasan = $this->resolveKaryawan($request);

        return ApiResponse::success(
            $this->leaveService->reject($atasan, $idIzin),
            'Pengajuan izin ditolak.'
        );
    }

    /**
     * GET /api/v1/team/recap?from=YYYY-MM-DD&to=YYYY-MM-DD
     */
    public function recap(TeamRecapRequest $request): JsonResponse
    {
        $atasan = $this->resolveKaryawan($request);

        return ApiResponse::success(
            $this->leaveService->getTeamRecap(
                $atasan,
                (string) $request->validated('from'),
                (string) $request->validated('to')
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
