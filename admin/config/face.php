<?php

return [
    /*
    |--------------------------------------------------------------------------
    | Face Recognition Configuration
    |--------------------------------------------------------------------------
    | Ambang sementara: akan diganti dari ml/artifacts/threshold.json
    | setelah evaluasi validasi model selesai (D-31).
    */
    'threshold' => (float) env('FACE_SIMILARITY_THRESHOLD', 0.75), // akan diganti dari ml/artifacts/threshold.json
    'embedding_dim' => (int) env('FACE_EMBEDDING_DIM', 128),
    'norm_tolerance' => (float) env('FACE_NORM_TOLERANCE', 0.05),
    'min_enroll_embeddings' => 3,
    'max_enroll_embeddings' => 5,
    'max_attempts' => (int) env('FACE_MAX_ATTEMPTS', 5),
    'storage_disk' => env('FACE_STORAGE_DISK', 'private'),
];
