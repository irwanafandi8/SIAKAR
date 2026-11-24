<?php

namespace App\Http\Controllers\Api\V1;

use App\Exceptions\DomainException;
use App\Http\Controllers\Controller;
use App\Http\Requests\LeaveStoreRequest;
use App\Models\Karyawan;
use App\Services\LeaveService;
use App\Support\ApiResponse;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class LeaveController extends Controller
{
    public function __construct(
        private readonly LeaveService $leaveService
    ) {}

    /**
     * GET /api/v1/leaves?status=
     */
    public function index(Request $request): JsonResponse
    {
        $karyawan = $this->resolveKaryawan($request);
        $status = $request->query('status');

        return ApiResponse::success(
            $this->leaveService->listLeaves($karyawan, is_string($status) ? $status : null)
        );
    }

    /**
     * POST /api/v1/leaves
     */
    public function store(LeaveStoreRequest $request): JsonResponse
    {
        $karyawan = $this->resolveKaryawan($request);

        $leave = $this->leaveService->createLeave(
            $karyawan,
            $request->validated(),
            $request->file('lampiran')
        );

        return ApiResponse::created($leave, 'Pengajuan izin berhasil dikirim.');
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
