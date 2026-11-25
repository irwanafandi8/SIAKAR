import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../design/tokens.dart';
import '../../features/auth/presentation/cubit/auth_cubit.dart';
import '../../features/auth/presentation/cubit/auth_state.dart';

class _NavTabSpec {
  final String path;
  final String label;
  final IconData icon;

  const _NavTabSpec({
    required this.path,
    required this.label,
    required this.icon,
  });
}

class MainShellPage extends StatelessWidget {
  final String location;
  final Widget child;

  const MainShellPage({
    super.key,
    required this.location,
    required this.child,
  });

  List<_NavTabSpec> _buildTabs(bool isAtasan) {
    return [
      const _NavTabSpec(path: '/home', label: 'Beranda', icon: Icons.home_outlined),
      const _NavTabSpec(path: '/history', label: 'Riwayat', icon: Icons.history),
      const _NavTabSpec(
        path: '/leave',
        label: 'Izin',
        icon: Icons.event_note_outlined,
      ),
      if (isAtasan) ...[
        const _NavTabSpec(
          path: '/approvals',
          label: 'Persetujuan',
          icon: Icons.fact_check_outlined,
        ),
        const _NavTabSpec(
          path: '/team',
          label: 'Rekap',
          icon: Icons.groups_outlined,
        ),
      ],
      const _NavTabSpec(
        path: '/profile',
        label: 'Profil',
        icon: Icons.person_outline,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthCubit>().state;
    final isAtasan = authState is Authenticated && authState.user.isAtasan;
    final tabs = _buildTabs(isAtasan);

    int currentIndex = tabs.indexWhere((t) => location.startsWith(t.path));
    if (currentIndex < 0) {
      currentIndex = 0;
    }

    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        backgroundColor: Tk.surface,
        indicatorColor: Tk.hadirBg,
        selectedIndex: currentIndex,
        onDestinationSelected: (idx) {
          final target = tabs[idx].path;
          if (target != location) {
            context.go(target);
          }
        },
        destinations: [
          for (final t in tabs)
            NavigationDestination(
              icon: Icon(t.icon, color: Tk.textMuted),
              selectedIcon: Icon(t.icon, color: Tk.primaryDark),
              label: t.label,
            ),
        ],
      ),
    );
  }
}
