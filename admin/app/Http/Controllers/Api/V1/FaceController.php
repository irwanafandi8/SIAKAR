<?php

namespace App\Http\Controllers\Api\V1;

use App\Exceptions\DomainException;
use App\Http\Controllers\Controller;
use App\Http\Requests\FaceEnrollRequest;
use App\Models\Karyawan;
use App\Services\FaceMatchService;
use App\Support\ApiResponse;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class FaceController extends Controller
{
    public function __construct(
        private readonly FaceMatchService $faceMatchService
    ) {}

    /**
     * GET /api/v1/face/status
     */
    public function status(Request $request): JsonResponse
    {
        $karyawan = $this->resolveKaryawan($request);

        return ApiResponse::success(
            $this->faceMatchService->getStatus($karyawan)
        );
    }

    /**
     * POST /api/v1/face/enroll
     */
    public function enroll(FaceEnrollRequest $request): JsonResponse
    {
        $karyawan = $this->resolveKaryawan($request);

        $this->faceMatchService->enroll(
            $karyawan,
            $request->decodedEmbeddings(),
            $request->file('photo'),
            (bool) $request->boolean('replace', false)
        );

        return ApiResponse::created(
            ['enrolled' => true],
            'Registrasi wajah berhasil.'
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
