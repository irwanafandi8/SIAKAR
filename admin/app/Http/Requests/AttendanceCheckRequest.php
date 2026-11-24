<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;

class AttendanceCheckRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    protected function prepareForValidation(): void
    {
        if ($this->has('liveness_passed')) {
            $raw = $this->input('liveness_passed');
            if (is_string($raw)) {
                $lower = strtolower(trim($raw));
                if (in_array($lower, ['true', '1'], true)) {
                    $this->merge(['liveness_passed' => true]);
                } elseif (in_array($lower, ['false', '0'], true)) {
                    $this->merge(['liveness_passed' => false]);
                }
            }
        }
    }

    /**
     * @return array<string, mixed>
     */
    public function rules(): array
    {
        return [
            'embedding'       => ['required', 'string'],
            'latitude'        => ['required', 'numeric', 'between:-90,90'],
            'longitude'       => ['required', 'numeric', 'between:-180,180'],
            'liveness_passed' => ['required', 'boolean'],
            'photo'           => ['required', 'file', 'mimes:jpg,jpeg,png', 'max:2048'],
            'device_id'       => ['nullable', 'string'],
        ];
    }
}
