<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('lokasi_kantor', function (Blueprint $table) {
            $table->id('id_lokasi');
            $table->string('nama_lokasi', 150);
            $table->decimal('latitude', 10, 8);
            $table->decimal('longitude', 11, 8);
            $table->integer('radius_meter')->default(100);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('lokasi_kantor');
    }
};
