import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../design/tokens.dart';
import '../../design/widgets/primary_button.dart';
import '../../design/widgets/status_badge.dart';
import '../auth/presentation/cubit/auth_cubit.dart';
import 'profile_feature.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  @override
  void initState() {
    super.initState();
    context.read<ProfileCubit>().loadProfile();
  }

  Future<void> _confirmLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Konfirmasi Keluar'),
        content: const Text('Apakah Anda yakin ingin keluar dari akun ini?'),
        actions: [
          TextButton(
            style: TextButton.styleFrom(
              minimumSize: const Size(Tk.minTouchTarget, Tk.minTouchTarget),
            ),
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Tk.alpaText,
              foregroundColor: Tk.onPrimary,
              minimumSize: const Size(Tk.minTouchTarget, Tk.minTouchTarget),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Keluar'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await context.read<ProfileCubit>().logout();
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<ProfileCubit, ProfileState>(
      listener: (context, state) {
        if (state is ProfileLoggedOut) {
          context.read<AuthCubit>().checkAuthStatus();
          context.go('/login');
        }
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Profil Karyawan')),
        body: BlocBuilder<ProfileCubit, ProfileState>(
          builder: (context, state) {
            if (state is ProfileLoading || state is ProfileInitial) {
              return const Center(child: CircularProgressIndicator());
            }

            if (state is ProfileFailure) {
              return Padding(
                padding: const EdgeInsets.all(Tk.spacing24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      state.failure.message,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: Tk.spacing16),
                    PrimaryButton(
                      text: 'Coba Lagi',
                      onPressed: () => context.read<ProfileCubit>().loadProfile(),
                    ),
                  ],
                ),
              );
            }

            if (state is! ProfileLoaded) {
              return const SizedBox.shrink();
            }

            final user = state.data.user;
            final face = state.data.faceStatus;

            return ListView(
              padding: const EdgeInsets.all(Tk.spacing16),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(Tk.spacing16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.nama,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: Tk.navy,
                          ),
                        ),
                        const SizedBox(height: Tk.spacing4),
                        Text(
                          'NIK: ${user.nik}',
                          style: const TextStyle(color: Tk.textMuted),
                        ),
                        const Divider(height: Tk.spacing24, color: Tk.outline),
                        _infoRow('Peran', user.role.toUpperCase()),
                        _infoRow('Departemen', user.departemen ?? '-'),
                        _infoRow('Jabatan', user.jabatan ?? '-'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: Tk.spacing16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(Tk.spacing16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Data Biometrik Wajah',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Tk.navy,
                              ),
                            ),
                            StatusBadge(
                              status: face.enrolled ? 'disetujui' : 'menunggu',
                            ),
                          ],
                        ),
                        const SizedBox(height: Tk.spacing8),
                        Text(
                          face.enrolled
                              ? 'Wajah sudah terdaftar${face.enrolledAt != null ? ' (${face.enrolledAt})' : ''}.'
                              : 'Wajah belum didaftarkan.',
                          style: const TextStyle(fontSize: 13, color: Tk.textMuted),
                        ),
                        const SizedBox(height: Tk.spacing12),
                        PrimaryButton(
                          text: face.enrolled ? 'Perbarui Wajah' : 'Daftarkan Wajah',
                          icon: Icons.camera_front,
                          onPressed: () => context.push('/face/enroll'),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: Tk.spacing24),
                PrimaryButton(
                  text: 'Keluar Akun',
                  icon: Icons.logout,
                  backgroundColor: Tk.alpaText,
                  onPressed: _confirmLogout,
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Tk.textMuted, fontSize: 14)),
          Text(
            value,
            style: const TextStyle(
              color: Tk.navy,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
