<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\Pengguna;
use App\Support\ApiResponse;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;
use Carbon\Carbon;

class AuthController extends Controller
{
    /**
     * POST /api/v1/auth/login
     */
    public function login(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'username'  => 'required|string',
            'password'  => 'required|string',
            'device_id' => 'required|string',
        ]);

        $user = Pengguna::with(['karyawan.departemen', 'karyawan.jabatan'])
            ->where('username', $validated['username'])
            ->first();

        if (!$user || !Hash::check($validated['password'], $user->password_hash)) {
            return ApiResponse::error(
                'Username atau password salah.',
                'INVALID_CREDENTIALS',
                401
            );
        }

        // Hanya karyawan dan atasan yang boleh login ke API mobile (Admin login lewat web)
        if ($user->role === Pengguna::ROLE_ADMIN) {
            return ApiResponse::error(
                'Akun admin hanya dapat masuk melalui panel web.',
                'FORBIDDEN_ROLE',
                403
            );
        }

        // Pengikatan Perangkat (Device Binding)
        if (empty($user->device_id)) {
            $user->device_id = $validated['device_id'];
        } elseif ($user->device_id !== $validated['device_id']) {
            return ApiResponse::error(
                'Perangkat tidak sesuai dengan yang terdaftar.',
                'DEVICE_MISMATCH',
                403
            );
        }

        $user->last_login = Carbon::now('Asia/Jakarta');
        $user->save();

        $token = $user->createToken('siakar-mobile-token')->plainTextToken;

        return ApiResponse::success([
            'token' => $token,
            'user'  => $this->formatUser($user),
        ], 'Login berhasil');
    }

    /**
     * POST /api/v1/auth/logout
     */
    public function logout(Request $request): JsonResponse
    {
        $request->user()->currentAccessToken()->delete();

        return ApiResponse::success(null, 'Berhasil logout');
    }

    /**
     * GET /api/v1/me
     */
    public function me(Request $request): JsonResponse
    {
        $user = $request->user()->load(['karyawan.departemen', 'karyawan.jabatan']);

        return ApiResponse::success($this->formatUser($user));
    }

    private function formatUser(Pengguna $user): array
    {
        $karyawan = $user->karyawan;
        $hasFace = $karyawan ? $karyawan->dataWajah()->where('aktif', true)->exists() : false;

        return [
            'id_pengguna'   => $user->id_pengguna,
            'id_karyawan'   => $karyawan?->id_karyawan,
            'username'      => $user->username,
            'nama'          => $karyawan?->nama,
            'nik'           => $karyawan?->nik,
            'role'          => $user->role,
            'departemen'    => $karyawan?->departemen?->nama_departemen,
            'jabatan'       => $karyawan?->jabatan?->nama_jabatan,
            'face_enrolled' => $hasFace,
        ];
    }
}
