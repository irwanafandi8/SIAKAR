<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('karyawan', function (Blueprint $table) {
            $table->id('id_karyawan');
            $table->string('nik', 50)->unique();
            $table->string('nama', 150);
            $table->enum('jenis_kelamin', ['L', 'P']);
            $table->date('tanggal_lahir');
            $table->string('email', 150)->nullable();
            $table->string('no_hp', 30)->nullable();
            $table->text('alamat')->nullable();
            $table->date('tanggal_masuk');
            $table->foreignId('id_departemen')->nullable()->constrained('departemen', 'id_departemen')->nullOnDelete();
            $table->foreignId('id_jabatan')->nullable()->constrained('jabatan', 'id_jabatan')->nullOnDelete();
            $table->foreignId('id_atasan')->nullable()->constrained('karyawan', 'id_karyawan')->nullOnDelete();
            $table->boolean('status_aktif')->default(true);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('karyawan');
    }
};
