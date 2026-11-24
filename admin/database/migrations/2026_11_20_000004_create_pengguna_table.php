<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('pengguna', function (Blueprint $table) {
            $table->id('id_pengguna');
            $table->foreignId('id_karyawan')->nullable()->constrained('karyawan', 'id_karyawan')->cascadeOnDelete();
            $table->string('username', 100)->unique();
            $table->string('password_hash', 255);
            $table->enum('role', ['karyawan', 'atasan', 'admin'])->default('karyawan');
            $table->string('device_id', 255)->nullable();
            $table->dateTime('last_login')->nullable();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('pengguna');
    }
};
