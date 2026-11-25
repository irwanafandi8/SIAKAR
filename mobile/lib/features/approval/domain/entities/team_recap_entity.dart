import 'package:equatable/equatable.dart';

class SubordinateRecapItem extends Equatable {
  final int idKaryawan;
  final String nama;
  final int hadir;
  final int terlambat;
  final int izin;
  final int sakit;
  final int cuti;
  final int alpa;

  const SubordinateRecapItem({
    required this.idKaryawan,
    required this.nama,
    required this.hadir,
    required this.terlambat,
    required this.izin,
    required this.sakit,
    required this.cuti,
    required this.alpa,
  });

  @override
  List<Object?> get props => [
        idKaryawan,
        nama,
        hadir,
        terlambat,
        izin,
        sakit,
        cuti,
        alpa,
      ];
}
