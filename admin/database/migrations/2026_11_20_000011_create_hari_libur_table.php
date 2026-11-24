<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('hari_libur', function (Blueprint $table) {
            $table->id('id_libur');
            $table->date('tanggal')->unique('uk_hari_libur_tanggal');
            $table->string('keterangan', 255);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('hari_libur');
    }
};
