import 'package:equatable/equatable.dart';

class AttendanceRecord extends Equatable {
  final int idAbsensi;
  final String tanggal;
  final String? jamMasuk;
  final String? jamPulang;
  final String status;
  final double? skorWajah;
  final String? lokasi;
  final String? keterangan;

  const AttendanceRecord({
    required this.idAbsensi,
    required this.tanggal,
    this.jamMasuk,
    this.jamPulang,
    required this.status,
    this.skorWajah,
    this.lokasi,
    this.keterangan,
  });

  bool get hasCheckedIn => jamMasuk != null && jamMasuk!.isNotEmpty;
  bool get hasCheckedOut => jamPulang != null && jamPulang!.isNotEmpty;

  @override
  List<Object?> get props => [
        idAbsensi,
        tanggal,
        jamMasuk,
        jamPulang,
        status,
        skorWajah,
        lokasi,
        keterangan,
      ];
}

class ShiftInfo extends Equatable {
  final String nama;
  final String jamMasuk;
  final String jamPulang;
  final int toleransiMenit;

  const ShiftInfo({
    required this.nama,
    required this.jamMasuk,
    required this.jamPulang,
    required this.toleransiMenit,
  });

  @override
  List<Object?> get props => [nama, jamMasuk, jamPulang, toleransiMenit];
}

class OfficeLocation extends Equatable {
  final int idLokasi;
  final String nama;
  final double latitude;
  final double longitude;
  final int radiusMeter;

  const OfficeLocation({
    required this.idLokasi,
    required this.nama,
    required this.latitude,
    required this.longitude,
    required this.radiusMeter,
  });

  @override
  List<Object?> get props => [idLokasi, nama, latitude, longitude, radiusMeter];
}

class TodayAttendanceInfo extends Equatable {
  final String tanggal;
  final bool hasSchedule;
  final bool isHoliday;
  final ShiftInfo? shift;
  final AttendanceRecord? attendance;
  final List<OfficeLocation> locations;

  const TodayAttendanceInfo({
    required this.tanggal,
    required this.hasSchedule,
    required this.isHoliday,
    this.shift,
    this.attendance,
    required this.locations,
  });

  bool get canCheckIn =>
      hasSchedule && !isHoliday && (attendance == null || !attendance!.hasCheckedIn);

  bool get canCheckOut =>
      hasSchedule &&
      !isHoliday &&
      attendance != null &&
      attendance!.hasCheckedIn &&
      !attendance!.hasCheckedOut;

  @override
  List<Object?> get props => [
        tanggal,
        hasSchedule,
        isHoliday,
        shift,
        attendance,
        locations,
      ];
}

class MonthlySummary extends Equatable {
  final int hadir;
  final int terlambat;
  final int izin;
  final int sakit;
  final int cuti;
  final int alpa;

  const MonthlySummary({
    required this.hadir,
    required this.terlambat,
    required this.izin,
    required this.sakit,
    required this.cuti,
    required this.alpa,
  });

  @override
  List<Object?> get props => [hadir, terlambat, izin, sakit, cuti, alpa];
}

class AttendanceHistory extends Equatable {
  final String month;
  final List<AttendanceRecord> items;
  final MonthlySummary summary;

  const AttendanceHistory({
    required this.month,
    required this.items,
    required this.summary,
  });

  @override
  List<Object?> get props => [month, items, summary];
}
