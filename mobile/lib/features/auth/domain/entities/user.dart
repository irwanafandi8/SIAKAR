import 'package:equatable/equatable.dart';

class User extends Equatable {
  final int idPengguna;
  final int? idKaryawan;
  final String nama;
  final String nik;
  final String role;
  final String? departemen;
  final String? jabatan;
  final bool faceEnrolled;

  const User({
    required this.idPengguna,
    this.idKaryawan,
    required this.nama,
    required this.nik,
    required this.role,
    this.departemen,
    this.jabatan,
    required this.faceEnrolled,
  });

  bool get isAtasan => role == 'atasan';
  bool get isKaryawan => role == 'karyawan';

  @override
  List<Object?> get props => [
        idPengguna,
        idKaryawan,
        nama,
        nik,
        role,
        departemen,
        jabatan,
        faceEnrolled,
      ];
}
