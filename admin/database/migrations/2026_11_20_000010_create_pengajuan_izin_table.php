<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('pengajuan_izin', function (Blueprint $table) {
            $table->id('id_izin');
            $table->foreignId('id_karyawan')->constrained('karyawan', 'id_karyawan')->cascadeOnDelete();
            $table->foreignId('id_penyetuju')->nullable()->constrained('karyawan', 'id_karyawan')->nullOnDelete();
            $table->enum('jenis', ['izin', 'sakit', 'cuti']);
            $table->date('tanggal_mulai');
            $table->date('tanggal_selesai');
            $table->text('alasan');
            $table->string('lampiran', 255)->nullable();
            $table->enum('status', ['menunggu', 'disetujui', 'ditolak'])->default('menunggu');
            $table->dateTime('tanggal_pengajuan');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('pengajuan_izin');
    }
};
