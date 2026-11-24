<?php

namespace App\Support;

use Illuminate\Http\JsonResponse;

class ApiResponse
{
    /**
     * Respon sukses seragam sesuai API.md §1
     */
    public static function success(mixed $data = null, string $message = 'OK', int $status = 200): JsonResponse
    {
        $payload = [
            'success' => true,
            'message' => $message,
            'data'    => $data ?? (object) [],
        ];

        return response()->json($payload, $status);
    }

    /**
     * Respon sukses pembuatan resource (HTTP 201)
     */
    public static function created(mixed $data = null, string $message = 'Berhasil dibuat'): JsonResponse
    {
        return self::success($data, $message, 201);
    }

    /**
     * Respon gagal seragam sesuai API.md §1
     */
    public static function error(
        string $message,
        string $code,
        int $status = 400,
        ?array $errors = null,
        ?array $extraData = null
    ): JsonResponse {
        $payload = [
            'success' => false,
            'message' => $message,
            'code'    => $code,
        ];

        if ($errors !== null && !empty($errors)) {
            $payload['errors'] = $errors;
        }

        if ($extraData !== null && !empty($extraData)) {
            $payload['data'] = $extraData;
        }

        return response()->json($payload, $status);
    }
}
