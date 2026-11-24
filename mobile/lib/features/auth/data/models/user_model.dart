import '../../domain/entities/user.dart';

class UserModel extends User {
  const UserModel({
    required super.idPengguna,
    super.idKaryawan,
    required super.nama,
    required super.nik,
    required super.role,
    super.departemen,
    super.jabatan,
    required super.faceEnrolled,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      idPengguna: json['id_pengguna'] as int? ?? 0,
      idKaryawan: json['id_karyawan'] as int?,
      nama: json['nama'] as String? ?? '',
      nik: json['nik'] as String? ?? '',
      role: json['role'] as String? ?? 'karyawan',
      departemen: json['departemen'] as String?,
      jabatan: json['jabatan'] as String?,
      faceEnrolled: json['face_enrolled'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id_pengguna': idPengguna,
      'id_karyawan': idKaryawan,
      'nama': nama,
      'nik': nik,
      'role': role,
      'departemen': departemen,
      'jabatan': jabatan,
      'face_enrolled': faceEnrolled,
    };
  }
}
