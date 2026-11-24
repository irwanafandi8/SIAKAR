import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/presentation/pages/login_page.dart';

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

final appRouter = GoRouter(
  navigatorKey: rootNavigatorKey,
  initialLocation: '/login',
  routes: [
    GoRoute(
      path: '/login',
      name: 'login',
      builder: (context, state) => const LoginPage(),
    ),
    GoRoute(
      path: '/home',
      name: 'home',
      builder: (context, state) => Scaffold(
        appBar: AppBar(title: const Text('Beranda SIAKAR')),
        body: const Center(
          child: Text(
            'Beranda Absensi SIAKAR\n(Fitur Absensi & Riwayat)',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    ),
  ],
);
