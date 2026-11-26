import '../../domain/entities/attendance_entities.dart';

class AttendanceRecordModel extends AttendanceRecord {
  const AttendanceRecordModel({
    required super.idAbsensi,
    required super.tanggal,
    super.jamMasuk,
    super.jamPulang,
    required super.status,
    super.skorWajah,
    super.lokasi,
    super.keterangan,
  });

  factory AttendanceRecordModel.fromJson(Map<String, dynamic> json) {
    return AttendanceRecordModel(
      idAbsensi: (json['id_absensi'] as num).toInt(),
      tanggal: json['tanggal']?.toString() ?? '',
      jamMasuk: json['jam_masuk']?.toString(),
      jamPulang: json['jam_pulang']?.toString(),
      status: json['status']?.toString() ?? 'hadir',
      skorWajah: json['skor_wajah'] != null
          ? (json['skor_wajah'] as num).toDouble()
          : null,
      lokasi: json['lokasi']?.toString(),
      keterangan: json['keterangan']?.toString(),
    );
  }
}

class ShiftInfoModel extends ShiftInfo {
  const ShiftInfoModel({
    required super.nama,
    required super.jamMasuk,
    required super.jamPulang,
    required super.toleransiMenit,
  });

  factory ShiftInfoModel.fromJson(Map<String, dynamic> json) {
    return ShiftInfoModel(
      nama: json['nama']?.toString() ?? '',
      jamMasuk: json['jam_masuk']?.toString() ?? '',
      jamPulang: json['jam_pulang']?.toString() ?? '',
      toleransiMenit: (json['toleransi_menit'] as num?)?.toInt() ?? 0,
    );
  }
}

class OfficeLocationModel extends OfficeLocation {
  const OfficeLocationModel({
    required super.idLokasi,
    required super.nama,
    required super.latitude,
    required super.longitude,
    required super.radiusMeter,
  });

  factory OfficeLocationModel.fromJson(Map<String, dynamic> json) {
    return OfficeLocationModel(
      idLokasi: (json['id_lokasi'] as num).toInt(),
      nama: json['nama']?.toString() ?? '',
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      radiusMeter: (json['radius_meter'] as num).toInt(),
    );
  }
}

class TodayAttendanceInfoModel extends TodayAttendanceInfo {
  const TodayAttendanceInfoModel({
    required super.tanggal,
    required super.hasSchedule,
    required super.isHoliday,
    super.shift,
    super.attendance,
    required super.locations,
  });

  factory TodayAttendanceInfoModel.fromJson(Map<String, dynamic> json) {
    final shiftJson = json['shift'] as Map<String, dynamic>?;
    final attendanceJson = json['attendance'] as Map<String, dynamic>?;
    final locationsRaw = json['locations'] as List<dynamic>? ?? const [];

    return TodayAttendanceInfoModel(
      tanggal: json['tanggal']?.toString() ?? '',
      hasSchedule: json['has_schedule'] == true,
      isHoliday: json['is_holiday'] == true,
      shift: shiftJson != null ? ShiftInfoModel.fromJson(shiftJson) : null,
      attendance: attendanceJson != null
          ? AttendanceRecordModel.fromJson(attendanceJson)
          : null,
      locations: locationsRaw
          .whereType<Map<String, dynamic>>()
          .map(OfficeLocationModel.fromJson)
          .toList(),
    );
  }
}

class MonthlySummaryModel extends MonthlySummary {
  const MonthlySummaryModel({
    required super.hadir,
    required super.terlambat,
    required super.izin,
    required super.sakit,
    required super.cuti,
    required super.alpa,
  });

  factory MonthlySummaryModel.fromJson(Map<String, dynamic> json) {
    return MonthlySummaryModel(
      hadir: (json['hadir'] as num?)?.toInt() ?? 0,
      terlambat: (json['terlambat'] as num?)?.toInt() ?? 0,
      izin: (json['izin'] as num?)?.toInt() ?? 0,
      sakit: (json['sakit'] as num?)?.toInt() ?? 0,
      cuti: (json['cuti'] as num?)?.toInt() ?? 0,
      alpa: (json['alpa'] as num?)?.toInt() ?? 0,
    );
  }
}

class AttendanceHistoryModel extends AttendanceHistory {
  const AttendanceHistoryModel({
    required super.month,
    required super.items,
    required super.summary,
  });

  factory AttendanceHistoryModel.fromJson(Map<String, dynamic> json) {
    final itemsRaw = json['items'] as List<dynamic>? ?? const [];
    final summaryRaw = json['summary'] as Map<String, dynamic>? ?? const {};

    return AttendanceHistoryModel(
      month: json['month']?.toString() ?? '',
      items: itemsRaw
          .whereType<Map<String, dynamic>>()
          .map(AttendanceRecordModel.fromJson)
          .toList(),
      summary: MonthlySummaryModel.fromJson(summaryRaw),
    );
  }
}

class AttendanceSubmissionResultModel extends AttendanceSubmissionResult {
  const AttendanceSubmissionResultModel({
    required super.mode,
    required super.attendance,
    super.similarity,
    super.distanceMeter,
    required super.status,
  });

  factory AttendanceSubmissionResultModel.fromJson(
    Map<String, dynamic> json, {
    required AttendanceMode mode,
  }) {
    final attJson = json['attendance'] as Map<String, dynamic>;
    final record = AttendanceRecordModel.fromJson(attJson);
    final sim = json['similarity'] != null
        ? (json['similarity'] as num).toDouble()
        : record.skorWajah;
    final dist = json['distance_meter'] != null
        ? (json['distance_meter'] as num).toDouble()
        : null;

    return AttendanceSubmissionResultModel(
      mode: mode,
      attendance: record,
      similarity: sim,
      distanceMeter: dist,
      status: json['status']?.toString() ?? record.status,
    );
  }
}
