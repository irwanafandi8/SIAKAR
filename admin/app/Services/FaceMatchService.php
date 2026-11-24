<?php

namespace App\Services;

use App\Exceptions\DomainException;
use App\Models\DataWajah;
use App\Models\Karyawan;
use Carbon\Carbon;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Crypt;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;
use Throwable;

class FaceMatchService
{
    /**
     * Validasi bentuk, ke-finite-an, dan norma L2 (~1.0) dari satu vektor embedding.
     *
     * @param  mixed  $embedding
     * @return list<float>
     *
     * @throws DomainException
     */
    public function validateEmbedding(mixed $embedding): array
    {
        $expectedDim = (int) config('face.embedding_dim', 128);
        $tolerance = (float) config('face.norm_tolerance', 0.05);

        if (!is_array($embedding) || !array_is_list($embedding) || count($embedding) !== $expectedDim) {
            throw new DomainException(
                "Embedding wajah harus berupa larik {$expectedDim} angka.",
                'INVALID_EMBEDDING',
                422
            );
        }

        $vector = [];
        $sumSq = 0.0;

        foreach ($embedding as $val) {
            if ((!is_int($val) && !is_float($val)) || !is_finite((float) $val)) {
                throw new DomainException(
                    'Nilai elemen embedding wajah tidak valid (mengandung non-angka atau NaN/Inf).',
                    'INVALID_EMBEDDING',
                    422
                );
            }

            $f = (float) $val;
            $vector[] = $f;
            $sumSq += $f * $f;
        }

        $norm = sqrt($sumSq);
        if (abs($norm - 1.0) > $tolerance) {
            throw new DomainException(
                'Embedding wajah belum ter-normalisasi L2 (norma menyimpang dari 1).',
                'INVALID_EMBEDDING',
                422
            );
        }

        return $vector;
    }

    /**
     * Normalisasi L2 pada vektor numerik sehingga panjangnya menjadi 1.0.
     *
     * @param  list<float|int>  $vector
     * @return list<float>
     *
     * @throws DomainException
     */
    public function l2Normalize(array $vector): array
    {
        if (empty($vector)) {
            throw new DomainException('Vektor embedding kosong.', 'INVALID_EMBEDDING', 422);
        }

        $sumSq = 0.0;
        foreach ($vector as $v) {
            $f = (float) $v;
            if (!is_finite($f)) {
                throw new DomainException('Vektor embedding mengandung NaN/Inf.', 'INVALID_EMBEDDING', 422);
            }
            $sumSq += $f * $f;
        }

        $norm = sqrt($sumSq);
        if ($norm <= 1e-12) {
            throw new DomainException('Norma vektor embedding bernilai nol.', 'INVALID_EMBEDDING', 422);
        }

        return array_map(static fn ($v): float => (float) $v / $norm, $vector);
    }

    /**
     * Validasi 3-5 embedding wajah, hitung rata-rata per dimensi, lalu L2-normalize.
     *
     * @param  array<int, mixed>  $embeddings
     * @return list<float>
     *
     * @throws DomainException
     */
    public function averageAndNormalize(array $embeddings): array
    {
        $minCount = (int) config('face.min_enroll_embeddings', 3);
        $maxCount = (int) config('face.max_enroll_embeddings', 5);
        $dim = (int) config('face.embedding_dim', 128);

        $count = count($embeddings);
        if ($count < $minCount || $count > $maxCount) {
            throw new DomainException(
                "Jumlah embedding registrasi harus antara {$minCount} sampai {$maxCount}.",
                'INVALID_EMBEDDING',
                422
            );
        }

        $mean = array_fill(0, $dim, 0.0);

        foreach ($embeddings as $emb) {
            $validated = $this->validateEmbedding($emb);
            for ($i = 0; $i < $dim; $i++) {
                $mean[$i] += $validated[$i];
            }
        }

        for ($i = 0; $i < $dim; $i++) {
            $mean[$i] /= $count;
        }

        return $this->l2Normalize($mean);
    }

    /**
     * Hitung cosine similarity murni antara dua vektor berdimensi sama.
     *
     * @param  list<float|int>  $vecA
     * @param  list<float|int>  $vecB
     */
    public function cosineSimilarity(array $vecA, array $vecB): float
    {
        $len = count($vecA);
        if ($len === 0 || $len !== count($vecB)) {
            throw new DomainException(
                'Dimensi kedua embedding tidak sama atau kosong.',
                'INVALID_EMBEDDING',
                422
            );
        }

        $dot = 0.0;
        $normASq = 0.0;
        $normBSq = 0.0;

        for ($i = 0; $i < $len; $i++) {
            $a = (float) $vecA[$i];
            $b = (float) $vecB[$i];
            $dot += $a * $b;
            $normASq += $a * $a;
            $normBSq += $b * $b;
        }

        $denom = sqrt($normASq) * sqrt($normBSq);
        if ($denom <= 1e-12) {
            throw new DomainException(
                'Norma embedding bernilai nol saat perhitungan cosine.',
                'INVALID_EMBEDDING',
                422
            );
        }

        $cosine = $dot / $denom;

        return max(-1.0, min(1.0, $cosine));
    }

    /**
     * Bandingkan embedding masuk dengan embedding terdaftar berdasarkan ambang config('face.threshold').
     *
     * @param  list<float>  $probeEmbedding
     * @param  list<float>  $enrolledEmbedding
     * @return array{matched: bool, similarity: float, threshold: float}
     */
    public function isMatch(array $probeEmbedding, array $enrolledEmbedding, ?float $threshold = null): array
    {
        $activeThreshold = $threshold ?? (float) config('face.threshold', 0.75);
        $similarity = $this->cosineSimilarity($probeEmbedding, $enrolledEmbedding);

        return [
            'matched'    => $similarity >= $activeThreshold,
            'similarity' => $similarity,
            'threshold'  => $activeThreshold,
        ];
    }

    /**
     * Enkripsi larik embedding menggunakan Laravel Crypt sebelum disimpan ke DB.
     *
     * @param  list<float>  $embedding
     */
    public function encryptEmbedding(array $embedding): string
    {
        return Crypt::encryptString(json_encode($embedding, JSON_THROW_ON_ERROR));
    }

    /**
     * Dekripsi ciphertext embedding dari DB kembali menjadi larik float.
     *
     * @return list<float>
     */
    public function decryptEmbedding(string $encrypted): array
    {
        $decoded = json_decode(Crypt::decryptString($encrypted), true, 512, JSON_THROW_ON_ERROR);

        return array_map(static fn ($v): float => (float) $v, $decoded);
    }

    /**
     * Ambil status registrasi wajah karyawan (GET /api/v1/face/status).
     *
     * @return array{enrolled: bool, enrolled_at: string|null}
     */
    public function getStatus(Karyawan $karyawan): array
    {
        $activeFace = DataWajah::where('id_karyawan', $karyawan->id_karyawan)
            ->where('aktif', true)
            ->latest('id_wajah')
            ->first();

        if (!$activeFace) {
            return [
                'enrolled'    => false,
                'enrolled_at' => null,
            ];
        }

        $enrolledAt = $activeFace->tanggal_daftar
            ? Carbon::parse($activeFace->tanggal_daftar)->timezone('Asia/Jakarta')->toIso8601String()
            : null;

        return [
            'enrolled'    => true,
            'enrolled_at' => $enrolledAt,
        ];
    }

    /**
     * Daftarkan atau perbarui data wajah karyawan (POST /api/v1/face/enroll).
     *
     * @param  array<int, mixed>  $embeddings
     *
     * @throws DomainException
     */
    public function enroll(Karyawan $karyawan, array $embeddings, UploadedFile $photo, bool $replace = false): void
    {
        $existingFaces = DataWajah::where('id_karyawan', $karyawan->id_karyawan)
            ->where('aktif', true)
            ->get();

        if ($existingFaces->isNotEmpty() && !$replace) {
            throw new DomainException(
                'Wajah sudah terdaftar. Gunakan replace=true untuk memperbarui data wajah.',
                'FACE_ALREADY_ENROLLED',
                409
            );
        }

        // Validasi tiap embedding, rata-ratakan, L2-normalize, lalu enkripsi
        $averagedNormalized = $this->averageAndNormalize($embeddings);
        $encryptedEmbedding = $this->encryptEmbedding($averagedNormalized);

        $diskName = (string) config('face.storage_disk', 'private');
        $storedPhotoPath = $photo->store("faces/{$karyawan->id_karyawan}", $diskName);

        if ($storedPhotoPath === false) {
            throw new DomainException(
                'Gagal menyimpan foto referensi wajah.',
                'SERVER_ERROR',
                500
            );
        }

        $oldPhotoPaths = $existingFaces
            ->pluck('foto_referensi')
            ->filter()
            ->values()
            ->all();

        try {
            DB::transaction(function () use ($karyawan, $encryptedEmbedding, $storedPhotoPath): void {
                // Hapus baris data wajah lama hanya di dalam transaksi saat data baru siap disimpan
                DataWajah::where('id_karyawan', $karyawan->id_karyawan)->delete();

                DataWajah::create([
                    'id_karyawan'    => $karyawan->id_karyawan,
                    'embedding'      => $encryptedEmbedding,
                    'foto_referensi' => $storedPhotoPath,
                    'tanggal_daftar' => Carbon::now('Asia/Jakarta'),
                    'aktif'          => true,
                ]);
            });
        } catch (Throwable $e) {
            Storage::disk($diskName)->delete($storedPhotoPath);
            throw $e;
        }

        // Bersihkan berkas foto referensi lama setelah transaksi DB sukses
        foreach ($oldPhotoPaths as $oldPath) {
            if ($oldPath !== $storedPhotoPath) {
                Storage::disk($diskName)->delete($oldPath);
            }
        }
    }
}
