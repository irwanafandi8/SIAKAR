<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('jadwal_karyawan', function (Blueprint $table) {
            $table->id('id_jadwal');
            $table->foreignId('id_karyawan')->constrained('karyawan', 'id_karyawan')->cascadeOnDelete();
            $table->foreignId('id_shift')->constrained('shift', 'id_shift')->cascadeOnDelete();
            $table->date('tanggal');

            $table->unique(['id_karyawan', 'tanggal'], 'uk_jadwal_karyawan_tanggal');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('jadwal_karyawan');
    }
};
