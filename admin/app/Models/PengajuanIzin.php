<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class PengajuanIzin extends Model
{
    protected $table = 'pengajuan_izin';
    protected $primaryKey = 'id_izin';
    public $timestamps = false;

    public const JENIS_IZIN = 'izin';
    public const JENIS_SAKIT = 'sakit';
    public const JENIS_CUTI = 'cuti';

    public const STATUS_MENUNGGU = 'menunggu';
    public const STATUS_DISETUJUI = 'disetujui';
    public const STATUS_DITOLAK = 'ditolak';

    protected $fillable = [
        'id_karyawan',
        'id_penyetuju',
        'jenis',
        'tanggal_mulai',
        'tanggal_selesai',
        'alasan',
        'lampiran',
        'status',
        'tanggal_pengajuan',
    ];

    protected $casts = [
        'tanggal_mulai'     => 'date',
        'tanggal_selesai'   => 'date',
        'tanggal_pengajuan' => 'datetime',
    ];

    public function karyawan(): BelongsTo
    {
        return $this->belongsTo(Karyawan::class, 'id_karyawan', 'id_karyawan');
    }

    public function penyetuju(): BelongsTo
    {
        return $this->belongsTo(Karyawan::class, 'id_penyetuju', 'id_karyawan');
    }
}
