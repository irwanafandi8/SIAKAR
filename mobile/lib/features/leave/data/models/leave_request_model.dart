import '../../domain/entities/leave_entities.dart';

class LeaveApplicantModel extends LeaveApplicant {
  const LeaveApplicantModel({
    required super.idKaryawan,
    required super.nama,
  });

  factory LeaveApplicantModel.fromJson(Map<String, dynamic> json) {
    return LeaveApplicantModel(
      idKaryawan: (json['id_karyawan'] as num?)?.toInt() ?? 0,
      nama: json['nama']?.toString() ?? '',
    );
  }
}

class LeaveRequestModel extends LeaveRequestEntity {
  const LeaveRequestModel({
    required super.idIzin,
    required super.jenis,
    required super.tanggalMulai,
    required super.tanggalSelesai,
    required super.alasan,
    super.lampiranUrl,
    required super.status,
    required super.pemohon,
    super.tanggalPengajuan,
  });

  factory LeaveRequestModel.fromJson(Map<String, dynamic> json) {
    final pemohonJson = json['pemohon'] as Map<String, dynamic>? ?? const {};

    return LeaveRequestModel(
      idIzin: (json['id_izin'] as num).toInt(),
      jenis: json['jenis']?.toString() ?? 'izin',
      tanggalMulai: json['tanggal_mulai']?.toString() ?? '',
      tanggalSelesai: json['tanggal_selesai']?.toString() ?? '',
      alasan: json['alasan']?.toString() ?? '',
      lampiranUrl: json['lampiran_url']?.toString(),
      status: json['status']?.toString() ?? 'menunggu',
      pemohon: LeaveApplicantModel.fromJson(pemohonJson),
      tanggalPengajuan: json['tanggal_pengajuan']?.toString(),
    );
  }
}
