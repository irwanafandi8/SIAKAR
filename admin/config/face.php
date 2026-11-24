<?php

return [
    /*
    |--------------------------------------------------------------------------
    | Face Recognition Configuration
    |--------------------------------------------------------------------------
    | Nilai threshold pencocokan wajah cosine similarity.
    | Dipilih dari evaluasi ml/artifacts/threshold.json (bisa di-override lewat .env)
    */
    'threshold' => (float) env('FACE_SIMILARITY_THRESHOLD', 0.75),
    'embedding_dim' => (int) env('FACE_EMBEDDING_DIM', 128),
    'max_attempts' => (int) env('FACE_MAX_ATTEMPTS', 5),
    'storage_disk' => env('FACE_STORAGE_DISK', 'private'),
];
