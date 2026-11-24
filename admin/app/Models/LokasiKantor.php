<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;

class LokasiKantor extends Model
{
    protected $table = 'lokasi_kantor';
    protected $primaryKey = 'id_lokasi';
    public $timestamps = false;

    protected $fillable = [
        'nama_lokasi',
        'latitude',
        'longitude',
        'radius_meter',
    ];

    protected $casts = [
        'latitude'     => 'float',
        'longitude'    => 'float',
        'radius_meter' => 'integer',
    ];

    public function absensi(): HasMany
    {
        return $this->hasMany(Absensi::class, 'id_lokasi', 'id_lokasi');
    }
}
