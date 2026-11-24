<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class Absensi extends Model
{
    protected $table = 'absensi';
    protected $primaryKey = 'id_absensi';
    public $timestamps = false;

    public const STATUS_HADIR = 'hadir';
    public const STATUS_TERLAMBAT = 'terlambat';
    public const STATUS_IZIN = 'izin';
    public const STATUS_SAKIT = 'sakit';
    public const STATUS_CUTI = 'cuti';
    public const STATUS_ALPA = 'alpa';

    protected $fillable = [
        'id_karyawan',
        'id_shift',
        'id_lokasi',
        'tanggal',
        'jam_masuk',
        'jam_pulang',
        'lat_masuk',
        'long_masuk',
        'lat_pulang',
        'long_pulang',
        'foto_masuk',
        'foto_pulang',
        'skor_wajah',
        'status',
        'keterangan',
    ];

    protected $casts = [
        'tanggal'     => 'date',
        'skor_wajah'  => 'float',
        'lat_masuk'   => 'float',
        'long_masuk'  => 'float',
        'lat_pulang'  => 'float',
        'long_pulang' => 'float',
    ];

    public function karyawan(): BelongsTo
    {
        return $this->belongsTo(Karyawan::class, 'id_karyawan', 'id_karyawan');
    }

    public function shift(): BelongsTo
    {
        return $this->belongsTo(Shift::class, 'id_shift', 'id_shift');
    }

    public function lokasi(): BelongsTo
    {
        return $this->belongsTo(LokasiKantor::class, 'id_lokasi', 'id_lokasi');
    }
}
