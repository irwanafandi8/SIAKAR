<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('absensi', function (Blueprint $table) {
            $table->id('id_absensi');
            $table->foreignId('id_karyawan')->constrained('karyawan', 'id_karyawan')->cascadeOnDelete();
            $table->foreignId('id_shift')->nullable()->constrained('shift', 'id_shift')->nullOnDelete();
            $table->foreignId('id_lokasi')->nullable()->constrained('lokasi_kantor', 'id_lokasi')->nullOnDelete();
            $table->date('tanggal');
            $table->time('jam_masuk')->nullable();
            $table->time('jam_pulang')->nullable();
            $table->decimal('lat_masuk', 10, 8)->nullable();
            $table->decimal('long_masuk', 11, 8)->nullable();
            $table->decimal('lat_pulang', 10, 8)->nullable();
            $table->decimal('long_pulang', 11, 8)->nullable();
            $table->string('foto_masuk', 255)->nullable();
            $table->string('foto_pulang', 255)->nullable();
            $table->decimal('skor_wajah', 5, 4)->nullable();
            $table->enum('status', ['hadir', 'terlambat', 'izin', 'sakit', 'cuti', 'alpa']);
            $table->text('keterangan')->nullable();

            $table->unique(['id_karyawan', 'tanggal'], 'uk_absensi_karyawan_tanggal');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('absensi');
    }
};
