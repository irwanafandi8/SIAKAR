<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('data_wajah', function (Blueprint $table) {
            $table->id('id_wajah');
            $table->foreignId('id_karyawan')->constrained('karyawan', 'id_karyawan')->cascadeOnDelete();
            $table->longText('embedding'); // Disimpan terenkripsi via Crypt
            $table->string('foto_referensi', 255)->nullable();
            $table->dateTime('tanggal_daftar');
            $table->boolean('aktif')->default(true);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('data_wajah');
    }
};
