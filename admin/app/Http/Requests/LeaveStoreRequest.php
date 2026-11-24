<?php

namespace App\Http\Requests;

use App\Models\PengajuanIzin;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class LeaveStoreRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    /**
     * @return array<string, mixed>
     */
    public function rules(): array
    {
        return [
            'jenis'           => ['required', 'string', Rule::in([
                PengajuanIzin::JENIS_IZIN,
                PengajuanIzin::JENIS_SAKIT,
                PengajuanIzin::JENIS_CUTI,
            ])],
            'tanggal_mulai'   => ['required', 'date_format:Y-m-d'],
            'tanggal_selesai' => ['required', 'date_format:Y-m-d', 'after_or_equal:tanggal_mulai'],
            'alasan'          => ['required', 'string', 'max:1000'],
            'lampiran'        => ['nullable', 'file', 'mimes:jpg,jpeg,png,pdf', 'max:2048'],
        ];
    }
}
