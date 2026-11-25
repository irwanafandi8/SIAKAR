import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../features/approval/presentation/cubit/approval_cubits.dart';
import '../../features/approval/presentation/pages/approval_pages.dart';
import '../../features/attendance/presentation/cubit/history_cubit.dart';
import '../../features/attendance/presentation/cubit/today_attendance_cubit.dart';
import '../../features/attendance/presentation/pages/history_page.dart';
import '../../features/attendance/presentation/pages/home_page.dart';
import '../../features/attendance/presentation/pages/placeholder_feature_page.dart';
import '../../features/auth/presentation/pages/login_page.dart';
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
      name: 'face_enroll_placeholder',
      builder: (context, state) => const PlaceholderFeaturePage(
        title: 'Registrasi Wajah',
        description:
            'Halaman kamera panduan oval & registrasi biometrik wajah (M5 / T-223) akan aktif setelah model TFLite tersedia.',
        icon: Icons.face_retouching_natural,
      ),
    ),
    GoRoute(
      parentNavigatorKey: rootNavigatorKey,
      path: '/attendance/capture',
      name: 'attendance_capture_placeholder',
      builder: (context, state) {
        final mode = state.uri.queryParameters['mode'] ?? 'check-in';
        final isOut = mode == 'check-out';
        return PlaceholderFeaturePage(
          title: isOut ? 'Absen Pulang' : 'Absen Masuk',
          description:
              'Halaman pengambilan GPS, kamera oval, dan pencocokan wajah (M6 / T-301) disiapkan sebagai placeholder navigasi.',
          icon: isOut ? Icons.logout : Icons.login,
        );
      },
    ),
  ],
);
