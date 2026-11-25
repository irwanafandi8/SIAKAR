import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:siakar_mobile/app/router/main_shell_page.dart';
import 'package:siakar_mobile/core/error/failures.dart';
import 'package:siakar_mobile/features/attendance/domain/entities/attendance_entities.dart';
import 'package:siakar_mobile/features/attendance/domain/repositories/attendance_repository.dart';
import 'package:siakar_mobile/features/attendance/domain/usecases/attendance_usecases.dart';
import 'package:siakar_mobile/features/attendance/presentation/cubit/history_cubit.dart';
import 'package:siakar_mobile/features/attendance/presentation/cubit/today_attendance_cubit.dart';
import 'package:siakar_mobile/features/auth/domain/entities/user.dart';
import 'package:siakar_mobile/features/auth/domain/repositories/auth_repository.dart';
import 'package:siakar_mobile/features/auth/domain/usecases/login_usecase.dart';
import 'package:siakar_mobile/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:siakar_mobile/features/profile/profile_feature.dart';

class FakeAttendanceRepository implements AttendanceRepository {
  bool shouldFail = false;
  TodayAttendanceInfo todayData = const TodayAttendanceInfo(
    tanggal: '2026-11-24',
    hasSchedule: true,
    isHoliday: false,
    shift: ShiftInfo(
      nama: 'Reguler',
      jamMasuk: '08:00:00',
      jamPulang: '16:00:00',
      toleransiMenit: 10,
    ),
    attendance: null,
    locations: [
      OfficeLocation(
        idLokasi: 1,
        nama: 'Kantor Pusat',
        latitude: -6.3277,
        longitude: 108.32,
        radiusMeter: 100,
      ),
    ],
  );

  @override
  Future<TodayAttendanceInfo> getTodayInfo() async {
    if (shouldFail) {
      throw const NetworkFailure();
    }
    return todayData;
  }

  @override
  Future<AttendanceHistory> getHistory({String? month}) async {
    if (shouldFail) {
      throw const ServerFailure(
        message: 'Gagal memuat riwayat.',
        code: 'SERVER_ERROR',
      );
    }
    return AttendanceHistory(
      month: month ?? '2026-11',
      items: const [
        AttendanceRecord(
          idAbsensi: 10,
          tanggal: '2026-11-24',
          jamMasuk: '07:55:00',
          jamPulang: '16:02:00',
          status: 'hadir',
          lokasi: 'Kantor Pusat',
        ),
      ],
      summary: const MonthlySummary(
        hadir: 1,
        terlambat: 0,
        izin: 0,
        sakit: 0,
        cuti: 0,
        alpa: 0,
      ),
    );
  }
}

class FakeAuthRepoForProfile implements AuthRepository {
  User? currentUser;
  bool loggedOutCalled = false;

  @override
  Future<User> login({
    required String username,
    required String password,
    required String deviceId,
  }) async {
    return currentUser!;
  }

  @override
  Future<void> logout() async {
    loggedOutCalled = true;
    currentUser = null;
  }

  @override
  Future<User?> getCurrentUser() async => currentUser;
}

class FakeProfileRepository implements ProfileRepository {
  @override
  Future<FaceEnrollmentStatus> getFaceStatus() async {
    return const FaceEnrollmentStatus(
      enrolled: true,
      enrolledAt: '2026-11-20T08:00:00+07:00',
    );
  }
}

void main() {
  group('M7 - TodayAttendanceCubit & HistoryCubit', () {
    late FakeAttendanceRepository repo;
    late TodayAttendanceCubit todayCubit;
    late HistoryCubit historyCubit;

    setUp(() {
      repo = FakeAttendanceRepository();
      todayCubit = TodayAttendanceCubit(
        getTodayAttendanceUseCase: GetTodayAttendanceUseCase(repo),
      );
      historyCubit = HistoryCubit(
        getAttendanceHistoryUseCase: GetAttendanceHistoryUseCase(repo),
      );
    });

    tearDown(() {
      todayCubit.close();
      historyCubit.close();
    });

    test('TodayAttendanceCubit emits [Loading, Success] and computes canCheckIn', () async {
      expectLater(
        todayCubit.stream,
        emitsInOrder([
          TodayAttendanceLoading(),
          isA<TodayAttendanceSuccess>()
              .having((s) => s.info.canCheckIn, 'canCheckIn', isTrue)
              .having((s) => s.info.canCheckOut, 'canCheckOut', isFalse),
        ]),
      );
      await todayCubit.loadToday();
    });

    test('TodayAttendanceCubit emits [Loading, Failure] on network error', () async {
      repo.shouldFail = true;
      expectLater(
        todayCubit.stream,
        emitsInOrder([
          TodayAttendanceLoading(),
          const TodayAttendanceFailure(NetworkFailure()),
        ]),
      );
      await todayCubit.loadToday();
    });

    test('HistoryCubit emits [Loading, Success] for requested month', () async {
      expectLater(
        historyCubit.stream,
        emitsInOrder([
          HistoryLoading(),
          isA<HistorySuccess>()
              .having((s) => s.history.month, 'month', '2026-11')
              .having((s) => s.history.summary.hadir, 'hadir', 1)
              .having((s) => s.history.items.length, 'items', 1),
        ]),
      );
      await historyCubit.loadHistory(month: '2026-11');
    });
  });

  group('M7 - ProfileCubit & Role-Aware Shell Navigation', () {
    late FakeAuthRepoForProfile authRepo;
    late ProfileCubit profileCubit;

    setUp(() {
      authRepo = FakeAuthRepoForProfile()
        ..currentUser = const User(
          idPengguna: 2,
          idKaryawan: 11,
          nama: 'Siti Rahmawati',
          nik: 'KRY-001',
          role: 'karyawan',
          departemen: 'TI',
          jabatan: 'Staff Senior',
          faceEnrolled: true,
        );
      profileCubit = ProfileCubit(
        getProfileInfoUseCase: GetProfileInfoUseCase(
          authRepository: authRepo,
          profileRepository: FakeProfileRepository(),
        ),
        logoutUseCase: LogoutUseCase(authRepo),
      );
    });

    tearDown(() {
      profileCubit.close();
    });

    test('ProfileCubit loads user + face status and logs out cleanly', () async {
      await profileCubit.loadProfile();
      expect(profileCubit.state, isA<ProfileLoaded>());
      final loaded = profileCubit.state as ProfileLoaded;
      expect(loaded.data.user.nama, 'Siti Rahmawati');
      expect(loaded.data.faceStatus.enrolled, isTrue);

      await profileCubit.logout();
      expect(profileCubit.state, equals(ProfileLoggedOut()));
      expect(authRepo.loggedOutCalled, isTrue);
    });

    testWidgets('MainShellPage hides supervisor tabs for karyawan and shows them for atasan',
        (tester) async {
      final authCubit = AuthCubit(
        loginUseCase: LoginUseCase(authRepo),
        authRepository: authRepo,
      );
      await authCubit.checkAuthStatus();

      await tester.pumpWidget(
        BlocProvider<AuthCubit>.value(
          value: authCubit,
          child: const MaterialApp(
            home: MainShellPage(
              location: '/home',
              child: Text('Konten Beranda'),
            ),
          ),
        ),
      );

      expect(find.text('Beranda'), findsOneWidget);
      expect(find.text('Riwayat'), findsOneWidget);
      expect(find.text('Izin'), findsOneWidget);
      expect(find.text('Profil'), findsOneWidget);
      expect(find.text('Persetujuan'), findsNothing);
      expect(find.text('Rekap'), findsNothing);

      // Ubah ke peran atasan -> tab Persetujuan & Rekap wajib tampil
      authRepo.currentUser = const User(
        idPengguna: 3,
        idKaryawan: 12,
        nama: 'Ahmad Fauzi',
        nik: 'ATS-001',
        role: 'atasan',
        faceEnrolled: true,
      );
      await authCubit.checkAuthStatus();
      await tester.pump();

      expect(find.text('Persetujuan'), findsOneWidget);
      expect(find.text('Rekap'), findsOneWidget);

      await authCubit.close();
    });
  });
}
