/// Pemetaan kode error API -> Pesan UI Bahasa Indonesia sesuai API.md §1
class ErrorMessages {
  static const Map<String, String> _messages = {
    'UNAUTHENTICATED': 'Sesi login telah berakhir. Silakan masuk kembali.',
    'INVALID_CREDENTIALS': 'Username atau kata sandi tidak sesuai.',
    'FORBIDDEN_ROLE': 'Peran Anda tidak berhak mengakses fitur ini.',
    'DEVICE_MISMATCH': 'Perangkat berbeda dari yang terikat dengan akun Anda. Hubungi Admin HRD untuk mereset perangkat.',
    'NOT_APPROVER': 'Anda bukan atasan langsung dari pemohon izin.',
    'NOT_FOUND': 'Data yang dicari tidak ditemukan.',
    'ALREADY_CHECKED_IN': 'Anda sudah melakukan absensi masuk hari ini.',
    'NOT_CHECKED_IN': 'Anda belum melakukan absensi masuk hari ini.',
    'ALREADY_CHECKED_OUT': 'Anda sudah melakukan absensi pulang hari ini.',
    'FACE_ALREADY_ENROLLED': 'Wajah sudah terdaftar. Gunakan opsi perbarui jika ingin mengganti data wajah.',
    'VALIDATION_ERROR': 'Data yang Anda masukkan tidak lengkap atau tidak valid.',
    'INVALID_EMBEDDING': 'Ekstraksi wajah gagal atau bentuk embedding tidak valid.',
    'FACE_NOT_ENROLLED': 'Wajah belum terdaftar. Silakan lakukan registrasi wajah terlebih dahulu.',
    'FACE_MISMATCH': 'Wajah tidak cocok dengan data terdaftar.',
    'LIVENESS_FAILED': 'Pemeriksaan keaslian wajah (liveness) gagal. Pastikan wajah asli terlihat jelas.',
    'OUT_OF_RADIUS': 'Anda berada di luar radius lokasi kantor yang ditentukan.',
    'NO_SCHEDULE': 'Tidak ada jadwal kerja untuk Anda pada hari ini.',
    'HOLIDAY': 'Hari ini adalah hari libur nasional / kantor.',
    'TOO_MANY_ATTEMPTS': 'Terlalu banyak percobaan. Harap tunggu beberapa saat sebelum mencoba lagi.',
    'SERVER_ERROR': 'Terjadi kesalahan pada server. Coba lagi nanti.',
    'NETWORK_ERROR': 'Koneksi jaringan terputus. Periksa sambungan data atau Wi-Fi Anda.',
  };

  static String fromCode(String? code, [String? fallbackMessage]) {
    if (code == null) {
      return fallbackMessage ?? 'Terjadi kesalahan. Silakan coba lagi.';
    }
    return _messages[code] ?? fallbackMessage ?? 'Terjadi kesalahan ($code).';
  }
}
