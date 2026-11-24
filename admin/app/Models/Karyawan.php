<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasOne;
use Illuminate\Database\Eloquent\Relations\HasMany;

class Karyawan extends Model
{
    protected $table = 'karyawan';
    protected $primaryKey = 'id_karyawan';
    public $timestamps = false;

    protected $fillable = [
        'nik',
        'nama',
        'jenis_kelamin',
        'tanggal_lahir',
        'email',
        'no_hp',
        'alamat',
        'tanggal_masuk',
        'id_departemen',
        'id_jabatan',
        'id_atasan',
        'status_aktif',
    ];

    protected $casts = [
        'status_aktif'  => 'boolean',
        'tanggal_lahir' => 'date',
        'tanggal_masuk' => 'date',
    ];

    public function departemen(): BelongsTo
    {
        return $this->belongsTo(Departemen::class, 'id_departemen', 'id_departemen');
    }

    public function jabatan(): BelongsTo
    {
        return $this->belongsTo(Jabatan::class, 'id_jabatan', 'id_jabatan');
    }

    public function atasan(): BelongsTo
    {
        return $this->belongsTo(Karyawan::class, 'id_atasan', 'id_karyawan');
    }

    public function bawahan(): HasMany
    {
        return $this->hasMany(Karyawan::class, 'id_atasan', 'id_karyawan');
    }

    public function pengguna(): HasOne
    {
        return $this->hasOne(Pengguna::class, 'id_karyawan', 'id_karyawan');
    }

    public function dataWajah(): HasOne
    {
        return $this->hasOne(DataWajah::class, 'id_karyawan', 'id_karyawan')->where('aktif', true);
    }

    public function absensi(): HasMany
    {
        return $this->hasMany(Absensi::class, 'id_karyawan', 'id_karyawan');
    }

    public function pengajuanIzin(): HasMany
    {
        return $this->hasMany(PengajuanIzin::class, 'id_karyawan', 'id_karyawan');
    }
}
