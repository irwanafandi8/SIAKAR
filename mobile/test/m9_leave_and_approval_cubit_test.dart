import 'package:flutter_test/flutter_test.dart';
import 'package:siakar_mobile/core/error/failures.dart';
import 'package:siakar_mobile/features/approval/domain/entities/team_recap_entity.dart';
import 'package:siakar_mobile/features/approval/domain/repositories/approval_repository.dart';
import 'package:siakar_mobile/features/approval/domain/usecases/approval_usecases.dart';
import 'package:siakar_mobile/features/approval/presentation/cubit/approval_cubits.dart';
import 'package:siakar_mobile/features/leave/domain/entities/leave_entities.dart';
import 'package:siakar_mobile/features/leave/domain/repositories/leave_repository.dart';
import 'package:siakar_mobile/features/leave/domain/usecases/leave_usecases.dart';
import 'package:siakar_mobile/features/leave/presentation/cubit/leave_cubit.dart';

class FakeLeaveRepository implements LeaveRepository {
  bool shouldFailOverlap = false;
  final List<LeaveRequestEntity> items = [
    const LeaveRequestEntity(
      idIzin: 1,
      jenis: 'sakit',
      tanggalMulai: '2026-11-25',
      tanggalSelesai: '2026-11-26',
      alasan: 'Demam tinggi',
      status: 'menunggu',
      pemohon: LeaveApplicant(idKaryawan: 11, nama: 'Siti Rahmawati'),
    ),
  ];

  @override
  Future<List<LeaveRequestEntity>> getMyLeaves({String? status}) async {
    if (status == null || status.isEmpty) {
      return List.unmodifiable(items);
    }
    return items.where((e) => e.status == status).toList();
  }

  @override
  Future<LeaveRequestEntity> submitLeave({
    required String jenis,
    required String tanggalMulai,
    required String tanggalSelesai,
    required String alasan,
    String? attachmentPath,
  }) async {
    if (shouldFailOverlap) {
      throw const ValidationFailure(
        message: 'Tanggal pengajuan tumpang tindih dengan pengajuan lain.',
      );
    }
    final created = LeaveRequestEntity(
      idIzin: 2,
      jenis: jenis,
      tanggalMulai: tanggalMulai,
      tanggalSelesai: tanggalSelesai,
      alasan: alasan,
      lampiranUrl: attachmentPath != null ? '/api/v1/leaves/2/attachment' : null,
      status: 'menunggu',
      pemohon: const LeaveApplicant(idKaryawan: 11, nama: 'Siti Rahmawati'),
    );
    items.insert(0, created);
    return created;
  }
}

class FakeApprovalRepository implements ApprovalRepository {
  bool failNotApprover = false;
  List<LeaveRequestEntity> store = [
    const LeaveRequestEntity(
      idIzin: 5,
      jenis: 'cuti',
      tanggalMulai: '2026-11-27',
      tanggalSelesai: '2026-11-28',
      alasan: 'Cuti keluarga',
      status: 'menunggu',
      pemohon: LeaveApplicant(idKaryawan: 11, nama: 'Siti Rahmawati'),
    ),
  ];

  @override
  Future<List<LeaveRequestEntity>> getApprovals({String? status}) async {
    if (status == null || status.isEmpty) return store;
    return store.where((e) => e.status == status).toList();
  }

  @override
  Future<LeaveRequestEntity> approveLeave(int idIzin) async {
    if (failNotApprover) {
      throw const ServerFailure(
        message: 'Anda bukan atasan langsung dari pemohon izin.',
        code: 'NOT_APPROVER',
      );
    }
    return _updateStatus(idIzin, 'disetujui');
  }

  @override
  Future<LeaveRequestEntity> rejectLeave(int idIzin) async {
    if (failNotApprover) {
      throw const ServerFailure(
        message: 'Anda bukan atasan langsung dari pemohon izin.',
        code: 'NOT_APPROVER',
      );
    }
    return _updateStatus(idIzin, 'ditolak');
  }

  LeaveRequestEntity _updateStatus(int idIzin, String newStatus) {
    final idx = store.indexWhere((e) => e.idIzin == idIzin);
    final old = store[idx];
    final updated = LeaveRequestEntity(
      idIzin: old.idIzin,
      jenis: old.jenis,
      tanggalMulai: old.tanggalMulai,
      tanggalSelesai: old.tanggalSelesai,
      alasan: old.alasan,
      status: newStatus,
      pemohon: old.pemohon,
    );
    store[idx] = updated;
    return updated;
  }

  @override
  Future<List<SubordinateRecapItem>> getTeamRecap({
    required String from,
    required String to,
  }) async {
    return const [
      SubordinateRecapItem(
        idKaryawan: 11,
        nama: 'Siti Rahmawati',
        hadir: 18,
        terlambat: 2,
        izin: 1,
        sakit: 0,
        cuti: 2,
        alpa: 0,
      ),
    ];
  }
}

void main() {
  group('M9 - LeaveCubit (Karyawan)', () {
    late FakeLeaveRepository repo;
    late LeaveCubit cubit;

    setUp(() {
      repo = FakeLeaveRepository();
      cubit = LeaveCubit(
        getMyLeavesUseCase: GetMyLeavesUseCase(repo),
        submitLeaveUseCase: SubmitLeaveUseCase(repo),
      );
    });

    tearDown(() {
      cubit.close();
    });

    test('loadLeaves filters by status and emits [LeaveLoading, LeaveLoaded]', () async {
      await cubit.loadLeaves(status: 'menunggu');
      expect(cubit.state, isA<LeaveLoaded>());
      final state = cubit.state as LeaveLoaded;
      expect(state.items.length, 1);
      expect(state.activeStatusFilter, 'menunggu');
    });

    test('submitLeave emits [LeaveSubmitting, LeaveSubmitSuccess] on valid input', () async {
      expectLater(
        cubit.stream,
        emitsInOrder([
          LeaveSubmitting(),
          isA<LeaveSubmitSuccess>()
              .having((s) => s.created.jenis, 'jenis', 'izin')
              .having((s) => s.created.status, 'status', 'menunggu'),
        ]),
      );

      await cubit.submitLeave(
        jenis: 'izin',
        tanggalMulai: '2026-12-01',
        tanggalSelesai: '2026-12-01',
        alasan: 'Keperluan administrasi',
      );
    });

    test('submitLeave emits [LeaveSubmitting, LeaveFailure] on overlapping dates', () async {
      repo.shouldFailOverlap = true;
      expectLater(
        cubit.stream,
        emitsInOrder([
          LeaveSubmitting(),
          isA<LeaveFailure>().having(
            (s) => s.failure.code,
            'code',
            'VALIDATION_ERROR',
          ),
        ]),
      );

      await cubit.submitLeave(
        jenis: 'sakit',
        tanggalMulai: '2026-11-25',
        tanggalSelesai: '2026-11-26',
        alasan: 'Overlap',
      );
    });
  });

  group('M9 - ApprovalCubit & TeamRecapCubit (Atasan)', () {
    late FakeApprovalRepository repo;
    late ApprovalCubit approvalCubit;
    late TeamRecapCubit recapCubit;

    setUp(() {
      repo = FakeApprovalRepository();
      approvalCubit = ApprovalCubit(
        getApprovalsUseCase: GetApprovalsUseCase(repo),
        approveLeaveUseCase: ApproveLeaveUseCase(repo),
        rejectLeaveUseCase: RejectLeaveUseCase(repo),
      );
      recapCubit = TeamRecapCubit(
        getTeamRecapUseCase: GetTeamRecapUseCase(repo),
      );
    });

    tearDown(() {
      approvalCubit.close();
      recapCubit.close();
    });

    test('ApprovalCubit approves pending leave and refreshes waiting list', () async {
      await approvalCubit.loadApprovals(status: 'menunggu');
      expect((approvalCubit.state as ApprovalLoaded).items.length, 1);

      await approvalCubit.decide(idIzin: 5, approve: true, currentStatus: 'menunggu');
      expect(approvalCubit.state, isA<ApprovalLoaded>());
      final after = approvalCubit.state as ApprovalLoaded;
      expect(after.items, isEmpty);
      expect(after.actionMessage, contains('disetujui'));
    });

    test('ApprovalCubit emits ApprovalFailure when server returns NOT_APPROVER', () async {
      repo.failNotApprover = true;
      await approvalCubit.decide(idIzin: 5, approve: false);
      expect(approvalCubit.state, isA<ApprovalFailure>());
      expect((approvalCubit.state as ApprovalFailure).failure.code, 'NOT_APPROVER');
    });

    test('TeamRecapCubit loads subordinate summary for period', () async {
      await recapCubit.loadRecap(from: '2026-11-01', to: '2026-11-30');
      expect(recapCubit.state, isA<TeamRecapSuccess>());
      final state = recapCubit.state as TeamRecapSuccess;
      expect(state.items.first.nama, 'Siti Rahmawati');
      expect(state.items.first.hadir, 18);
      expect(state.items.first.cuti, 2);
    });
  });
}
