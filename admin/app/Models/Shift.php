<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;

class Shift extends Model
{
    protected $table = 'shift';
    protected $primaryKey = 'id_shift';
    public $timestamps = false;

    protected $fillable = [
        'nama_shift',
        'jam_masuk',
        'jam_pulang',
        'toleransi_menit',
    ];

    protected $casts = [
        'toleransi_menit' => 'integer',
    ];

    public function jadwalKaryawan(): HasMany
    {
        return $this->hasMany(JadwalKaryawan::class, 'id_shift', 'id_shift');
    }
}
