import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../core/device/permission_service.dart';
import '../../core/ml/preprocess.dart';
import '../../features/approval/presentation/cubit/approval_cubits.dart';
import '../../features/approval/presentation/pages/approval_pages.dart';
import '../../features/attendance/domain/entities/attendance_entities.dart';
import '../../features/attendance/presentation/cubit/attendance_capture_cubit.dart';
import '../../features/attendance/presentation/cubit/history_cubit.dart';
import '../../features/attendance/presentation/cubit/today_attendance_cubit.dart';
import '../../features/attendance/presentation/pages/attendance_capture_page.dart';
import '../../features/attendance/presentation/pages/history_page.dart';
import '../../features/attendance/presentation/pages/home_page.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/face_enrollment/presentation/cubit/face_enrollment_cubit.dart';
import '../../features/face_enrollment/presentation/pages/face_enrollment_page.dart';
import '../../features/leave/presentation/cubit/leave_cubit.dart';
import '../../features/leave/presentation/pages/leave_form_page.dart';
import '../../features/leave/presentation/pages/leave_list_page.dart';
import '../../features/profile/profile_feature.dart';
import '../../features/profile/profile_page.dart';
import '../di/injection.dart';
import 'main_shell_page.dart';

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();
final GlobalKey<NavigatorState> shellNavigatorKey = GlobalKey<NavigatorState>();

final appRouter = GoRouter(
  navigatorKey: rootNavigatorKey,
  initialLocation: '/login',
  routes: [
    GoRoute(
      path: '/login',
      name: 'login',
      builder: (context, state) => const LoginPage(),
    ),
    ShellRoute(
      navigatorKey: shellNavigatorKey,
      builder: (context, state, child) => MainShellPage(
        location: state.matchedLocation,
        child: child,
      ),
      routes: [
        GoRoute(
          path: '/home',
          name: 'home',
          builder: (context, state) => BlocProvider<TodayAttendanceCubit>(
            create: (_) => sl<TodayAttendanceCubit>(),
            child: const HomePage(),
          ),
        ),
        GoRoute(
          path: '/history',
          name: 'history',
          builder: (context, state) => BlocProvider<HistoryCubit>(
            create: (_) => sl<HistoryCubit>(),
            child: const HistoryPage(),
          ),
        ),
        GoRoute(
          path: '/leave',
          name: 'leave',
          builder: (context, state) => BlocProvider<LeaveCubit>(
            create: (_) => sl<LeaveCubit>(),
            child: const LeaveListPage(),
          ),
        ),
        GoRoute(
          path: '/approvals',
          name: 'approvals',
          builder: (context, state) => BlocProvider<ApprovalCubit>(
            create: (_) => sl<ApprovalCubit>(),
            child: const ApprovalListPage(),
          ),
        ),
        GoRoute(
          path: '/team',
          name: 'team',
          builder: (context, state) => BlocProvider<TeamRecapCubit>(
            create: (_) => sl<TeamRecapCubit>(),
            child: const TeamRecapPage(),
          ),
        ),
        GoRoute(
          path: '/profile',
          name: 'profile',
          builder: (context, state) => BlocProvider<ProfileCubit>(
            create: (_) => sl<ProfileCubit>(),
            child: const ProfilePage(),
          ),
        ),
      ],
    ),
    GoRoute(
      parentNavigatorKey: rootNavigatorKey,
      path: '/leave/new',
      name: 'leave_new',
      builder: (context, state) => BlocProvider<LeaveCubit>(
        create: (_) => sl<LeaveCubit>(),
        child: const LeaveFormPage(),
      ),
    ),
    GoRoute(
      parentNavigatorKey: rootNavigatorKey,
      path: '/face/enroll',
      name: 'face_enroll',
      builder: (context, state) => BlocProvider<FaceEnrollmentCubit>(
        create: (_) => sl<FaceEnrollmentCubit>(),
        child: FaceEnrollmentPage(
          permissionService: sl<DevicePermissionService>(),
          preprocessConfig: sl<PreprocessService>().spec,
        ),
      ),
    ),
    GoRoute(
      parentNavigatorKey: rootNavigatorKey,
      path: '/attendance/capture',
      name: 'attendance_capture',
      builder: (context, state) {
        final mode = AttendanceMode.fromQuery(
          state.uri.queryParameters['mode'],
        );
        return BlocProvider<AttendanceCaptureCubit>(
          create: (_) => sl<AttendanceCaptureCubit>(),
          child: AttendanceCapturePage(
            mode: mode,
            permissionService: sl<DevicePermissionService>(),
            preprocessConfig: sl<PreprocessService>().spec,
          ),
        );
      },
    ),
  ],
);
