<?php

use Illuminate\Support\Facades\Route;
use App\Http\Controllers\Api\V1\AuthController;

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
    });

});
