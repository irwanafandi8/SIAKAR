<?php

namespace App\Models;

use Illuminate\Foundation\Auth\User as Authenticatable;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Laravel\Sanctum\HasApiTokens;

class Pengguna extends Authenticatable
{
    use HasApiTokens;

    protected $table = 'pengguna';
    protected $primaryKey = 'id_pengguna';
    public $timestamps = false;

    public const ROLE_KARYAWAN = 'karyawan';
    public const ROLE_ATASAN = 'atasan';
    public const ROLE_ADMIN = 'admin';

    protected $fillable = [
        'id_karyawan',
        'username',
        'password_hash',
        'role',
        'device_id',
        'last_login',
    ];

    protected $hidden = [
        'password_hash',
    ];

    protected $casts = [
        'last_login' => 'datetime',
    ];

    /**
     * Override getAuthPassword untuk menggunakan password_hash sesuai skema kamus data
     */
    public function getAuthPassword(): string
    {
        return $this->password_hash;
    }

    public function karyawan(): BelongsTo
    {
        return $this->belongsTo(Karyawan::class, 'id_karyawan', 'id_karyawan');
    }

    public function isRole(string $role): bool
    {
        return $this->role === $role;
    }
}
