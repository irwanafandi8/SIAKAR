<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class JadwalKaryawan extends Model
{
    protected $table = 'jadwal_karyawan';
    protected $primaryKey = 'id_jadwal';
    public $timestamps = false;

    protected $fillable = [
        'id_karyawan',
        'id_shift',
        'tanggal',
    ];

    protected $casts = [
        'tanggal' => 'date',
    ];

    public function karyawan(): BelongsTo
    {
        return $this->belongsTo(Karyawan::class, 'id_karyawan', 'id_karyawan');
    }

    public function shift(): BelongsTo
    {
        return $this->belongsTo(Shift::class, 'id_shift', 'id_shift');
    }
}
