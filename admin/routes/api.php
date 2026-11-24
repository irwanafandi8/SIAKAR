<?php

use Illuminate\Support\Facades\Route;
use App\Http\Controllers\Api\V1\ApprovalController;
use App\Http\Controllers\Api\V1\AttendanceController;
use App\Http\Controllers\Api\V1\AuthController;
use App\Http\Controllers\Api\V1\FaceController;
use App\Http\Controllers\Api\V1\LeaveController;

/*
|--------------------------------------------------------------------------
| API Routes SIAKAR — v1
|--------------------------------------------------------------------------
| Sesuai kontrak API.md §6
*/

Route::prefix('v1')->group(function () {

    // Auth Publik
    Route::post('/auth/login', [AuthController::class, 'login']);

    // Terproteksi Token Sanctum
    Route::middleware(['auth:sanctum'])->group(function () {
        Route::post('/auth/logout', [AuthController::class, 'logout']);
        Route::get('/me', [AuthController::class, 'me']);

        // Wajah & Absensi (khusus karyawan & atasan sesuai API.md §6)
        Route::middleware(['role:karyawan,atasan'])->group(function () {
            Route::get('/face/status', [FaceController::class, 'status']);
            Route::post('/face/enroll', [FaceController::class, 'enroll']);

            Route::get('/attendance/today', [AttendanceController::class, 'today']);
            Route::get('/attendance/history', [AttendanceController::class, 'history']);

            Route::middleware(['device.bound', 'throttle:attendance'])->group(function () {
                Route::post('/attendance/check-in', [AttendanceController::class, 'checkIn']);
                Route::post('/attendance/check-out', [AttendanceController::class, 'checkOut']);
            });

            Route::get('/leaves', [LeaveController::class, 'index']);
            Route::post('/leaves', [LeaveController::class, 'store']);
        });

        // Persetujuan & Rekap Tim (khusus atasan sesuai API.md §6)
        Route::middleware(['role:atasan'])->group(function () {
            Route::get('/approvals', [ApprovalController::class, 'index']);
            Route::post('/approvals/{id_izin}/approve', [ApprovalController::class, 'approve']);
            Route::post('/approvals/{id_izin}/reject', [ApprovalController::class, 'reject']);
            Route::get('/team/recap', [ApprovalController::class, 'recap']);
        });
    });

});
