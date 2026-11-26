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
    'CAMERA_PERMISSION_DENIED': 'Izin kamera ditolak. Izinkan akses kamera untuk mengambil foto wajah.',
    'CAMERA_PERMISSION_PERMANENTLY_DENIED': 'Izin kamera ditolak permanen. Buka Pengaturan Aplikasi untuk mengaktifkan izin kamera.',
    'CAMERA_UNAVAILABLE': 'Kamera depan tidak ditemukan atau gagal diinisialisasi pada perangkat ini.',
    'LOCATION_SERVICE_DISABLED': 'Layanan lokasi (GPS) mati. Aktifkan GPS perangkat Anda terlebih dahulu.',
    'LOCATION_PERMISSION_DENIED': 'Izin lokasi ditolak. Izinkan akses lokasi untuk memverifikasi area kantor.',
    'LOCATION_PERMISSION_PERMANENTLY_DENIED': 'Izin lokasi ditolak permanen. Buka Pengaturan Aplikasi untuk mengaktifkan izin lokasi.',
    'MOCK_LOCATION_DETECTED': 'Lokasi palsu (Mock GPS) terdeteksi. Matikan aplikasi lokasi palsu untuk melanjutkan.',
    'FACE_NOT_IN_OVAL': 'Wajah tidak terdeteksi dengan jelas di dalam bingkai oval. Pastikan wajah berada di tengah oval dengan pencahayaan cukup.',
    'LIGHTING_TOO_DARK': 'Cahaya kurang terang. Pindah ke tempat dengan pencahayaan lebih baik.',
    'LIGHTING_TOO_BRIGHT': 'Cahaya terlalu silau. Hindari sumber cahaya langsung di belakang atau depan wajah.',
  };

  static String fromCode(String? code, [String? fallbackMessage]) {
    if (code == null) {
      return fallbackMessage ?? 'Terjadi kesalahan. Silakan coba lagi.';
    }
    return _messages[code] ?? fallbackMessage ?? 'Terjadi kesalahan ($code).';
  }
}
