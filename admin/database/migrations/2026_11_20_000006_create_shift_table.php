<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('shift', function (Blueprint $table) {
            $table->id('id_shift');
            $table->string('nama_shift', 100);
            $table->time('jam_masuk');
            $table->time('jam_pulang');
            $table->integer('toleransi_menit')->default(10);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('shift');
    }
};
