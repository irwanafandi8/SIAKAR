<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class DataWajah extends Model
{
    protected $table = 'data_wajah';
    protected $primaryKey = 'id_wajah';
    public $timestamps = false;

    protected $fillable = [
        'id_karyawan',
        'embedding',
        'foto_referensi',
        'tanggal_daftar',
        'aktif',
    ];

    protected $casts = [
        'aktif'          => 'boolean',
        'tanggal_daftar' => 'datetime',
    ];

    public function karyawan(): BelongsTo
    {
        return $this->belongsTo(Karyawan::class, 'id_karyawan', 'id_karyawan');
    }
}
