<?php

use App\Http\Controllers\Admin\AbsensiController;
use App\Http\Controllers\Admin\AuthController;
use App\Http\Controllers\Admin\DepartemenController;
use App\Http\Controllers\Admin\HariLiburController;
use App\Http\Controllers\Admin\JabatanController;
use App\Http\Controllers\Admin\JadwalController;
use App\Http\Controllers\Admin\KaryawanController;
use App\Http\Controllers\Admin\LaporanController;
use App\Http\Controllers\Admin\LokasiController;
use App\Http\Controllers\Admin\ShiftController;
use Illuminate\Support\Facades\Route;

Route::get('/', function () {
    return redirect()->route('admin.dashboard');
});

Route::prefix('admin')->name('admin.')->group(function () {
    Route::get('/login', [AuthController::class, 'showLogin'])->name('login');
    Route::post('/login', [AuthController::class, 'login'])->name('login.submit');

    Route::middleware(['auth', 'role:admin'])->group(function () {
        Route::post('/logout', [AuthController::class, 'logout'])->name('logout');
        Route::get('/', fn () => view('admin.dashboard'))->name('dashboard');

        Route::resource('departemen', DepartemenController::class)
            ->parameters(['departemen' => 'departemen'])
            ->except(['show']);
        Route::resource('jabatan', JabatanController::class)->except(['show']);

        Route::resource('karyawan', KaryawanController::class)->except(['show', 'destroy']);
        Route::post('karyawan/{karyawan}/deactivate', [KaryawanController::class, 'deactivate'])->name('karyawan.deactivate');
        Route::post('karyawan/{karyawan}/reset-face', [KaryawanController::class, 'resetFace'])->name('karyawan.reset-face');
        Route::post('karyawan/{karyawan}/reset-device', [KaryawanController::class, 'resetDevice'])->name('karyawan.reset-device');

        Route::resource('shift', ShiftController::class)->except(['show']);
        Route::resource('jadwal', JadwalController::class)->except(['show']);
        Route::resource('lokasi', LokasiController::class)->except(['show']);
        Route::resource('hari-libur', HariLiburController::class)
            ->parameters(['hari-libur' => 'hariLibur'])
            ->except(['show']);

        Route::get('absensi', [AbsensiController::class, 'index'])->name('absensi.index');
        Route::get('absensi/{absensi}/edit', [AbsensiController::class, 'edit'])->name('absensi.edit');
        Route::put('absensi/{absensi}', [AbsensiController::class, 'update'])->name('absensi.update');
        Route::get('absensi/{absensi}/photo/{type}', [AbsensiController::class, 'photo'])->name('absensi.photo');

        Route::get('laporan', [LaporanController::class, 'index'])->name('laporan.index');
        Route::get('laporan/export-csv', [LaporanController::class, 'exportCsv'])->name('laporan.export-csv');
    });
});
