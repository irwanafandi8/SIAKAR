<?php

namespace App\Http\Middleware;

use App\Support\ApiResponse;
use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

class EnsureDeviceBound
{
    /**
     * Pastikan akun pengguna memiliki perangkat terikat dan cocok bila klien menyertakan device_id.
     *
     * @param  \Closure(\Illuminate\Http\Request): (\Symfony\Component\HttpFoundation\Response)  $next
     */
    public function handle(Request $request, Closure $next): Response
    {
        $user = $request->user();

        if (!$user) {
            return ApiResponse::error(
                'Token tidak ada atau telah kedaluwarsa.',
                'UNAUTHENTICATED',
                401
            );
        }

        if (empty($user->device_id)) {
            return ApiResponse::error(
                'Perangkat belum terikat atau telah direset. Silakan login kembali.',
                'DEVICE_MISMATCH',
                403
            );
        }

        $providedDeviceId = $request->input('device_id') ?? $request->header('X-Device-Id');
        if (is_string($providedDeviceId) && trim($providedDeviceId) !== '' && $providedDeviceId !== $user->device_id) {
            return ApiResponse::error(
                'Perangkat tidak sesuai dengan yang terdaftar.',
                'DEVICE_MISMATCH',
                403
            );
        }

        return $next($request);
    }
}
