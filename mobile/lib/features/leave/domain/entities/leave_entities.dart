import 'package:equatable/equatable.dart';

class LeaveApplicant extends Equatable {
  final int idKaryawan;
  final String nama;

  const LeaveApplicant({
    required this.idKaryawan,
    required this.nama,
  });

  @override
  List<Object?> get props => [idKaryawan, nama];
}

class LeaveRequestEntity extends Equatable {
  final int idIzin;
  final String jenis;
  final String tanggalMulai;
  final String tanggalSelesai;
  final String alasan;
  final String? lampiranUrl;
  final String status;
  final LeaveApplicant pemohon;
  final String? tanggalPengajuan;

  const LeaveRequestEntity({
    required this.idIzin,
    required this.jenis,
    required this.tanggalMulai,
    required this.tanggalSelesai,
    required this.alasan,
    this.lampiranUrl,
    required this.status,
    required this.pemohon,
    this.tanggalPengajuan,
  });

  bool get isPending => status == 'menunggu';

  @override
  List<Object?> get props => [
        idIzin,
        jenis,
        tanggalMulai,
        tanggalSelesai,
        alasan,
        lampiranUrl,
        status,
        pemohon,
        tanggalPengajuan,
      ];
}
