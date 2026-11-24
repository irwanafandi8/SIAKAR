<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;

class Departemen extends Model
{
    protected $table = 'departemen';
    protected $primaryKey = 'id_departemen';
    public $timestamps = false;

    protected $fillable = [
        'nama_departemen',
    ];

    public function karyawan(): HasMany
    {
        return $this->hasMany(Karyawan::class, 'id_departemen', 'id_departemen');
    }
}
