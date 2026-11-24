<?php

namespace App\Http\Requests;

use Closure;
use Illuminate\Foundation\Http\FormRequest;

class FaceEnrollRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    protected function prepareForValidation(): void
    {
        if ($this->has('replace')) {
            $raw = $this->input('replace');
            if (is_string($raw)) {
                $lower = strtolower(trim($raw));
                if (in_array($lower, ['true', '1'], true)) {
                    $this->merge(['replace' => true]);
                } elseif (in_array($lower, ['false', '0', ''], true)) {
                    $this->merge(['replace' => false]);
                }
            }
        }
    }

    /**
     * @return array<string, mixed>
     */
    public function rules(): array
    {
        $minCount = (int) config('face.min_enroll_embeddings', 3);
        $maxCount = (int) config('face.max_enroll_embeddings', 5);

        return [
            'embeddings' => [
                'required',
                'string',
                function (string $attribute, mixed $value, Closure $fail) use ($minCount, $maxCount): void {
                    $decoded = json_decode((string) $value, true);
                    if (json_last_error() !== JSON_ERROR_NONE || !is_array($decoded) || !array_is_list($decoded)) {
                        $fail('Field embeddings harus berupa string JSON larik embedding.');
                        return;
                    }

                    $count = count($decoded);
                    if ($count < $minCount || $count > $maxCount) {
                        $fail("Jumlah foto/embedding wajib antara {$minCount} hingga {$maxCount}.");
                    }
                },
            ],
            'photo'   => ['required', 'file', 'mimes:jpg,jpeg,png', 'max:2048'],
            'replace' => ['nullable', 'boolean'],
        ];
    }

    /**
     * Ambil larik embedding hasil decode JSON setelah lolos validasi.
     *
     * @return array<int, mixed>
     */
    public function decodedEmbeddings(): array
    {
        /** @var array<int, mixed> $decoded */
        $decoded = json_decode((string) $this->validated('embeddings'), true);

        return $decoded;
    }
}
