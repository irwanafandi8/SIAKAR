import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../design/tokens.dart';
import '../../../../design/widgets/primary_button.dart';
import '../../../../design/widgets/status_badge.dart';
import '../../../auth/presentation/cubit/auth_cubit.dart';
import '../../../auth/presentation/cubit/auth_state.dart';
import '../../domain/entities/attendance_entities.dart';
import '../cubit/today_attendance_cubit.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  void initState() {
    super.initState();
    context.read<TodayAttendanceCubit>().loadToday();
  }

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthCubit>().state;
    final user = authState is Authenticated ? authState.user : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Beranda SIAKAR'),
        actions: [
          IconButton(
            tooltip: 'Muat Ulang',
            constraints: const BoxConstraints(
              minWidth: Tk.minTouchTarget,
              minHeight: Tk.minTouchTarget,
            ),
            onPressed: () => context.read<TodayAttendanceCubit>().loadToday(),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: BlocBuilder<TodayAttendanceCubit, TodayAttendanceState>(
        builder: (context, state) {
          if (state is TodayAttendanceLoading || state is TodayAttendanceInitial) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state is TodayAttendanceFailure) {
            return Padding(
              padding: const EdgeInsets.all(Tk.spacing24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Tk.alpaText),
                  const SizedBox(height: Tk.spacing12),
                  Text(
                    state.failure.message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Tk.navy, fontSize: 15),
                  ),
                  const SizedBox(height: Tk.spacing16),
                  PrimaryButton(
                    text: 'Coba Lagi',
                    icon: Icons.refresh,
                    onPressed: () =>
                        context.read<TodayAttendanceCubit>().loadToday(),
                  ),
                ],
              ),
            );
          }

          final info = (state as TodayAttendanceSuccess).info;
          final faceEnrolled = user?.faceEnrolled ?? false;

          return RefreshIndicator(
            onRefresh: () => context.read<TodayAttendanceCubit>().loadToday(),
            child: ListView(
              padding: const EdgeInsets.all(Tk.spacing16),
              children: [
                _buildGreetingCard(user?.nama ?? 'Karyawan', user?.jabatan, info.tanggal),
                const SizedBox(height: Tk.spacing16),
                _buildScheduleCard(info),
                const SizedBox(height: Tk.spacing16),
                _buildAttendanceStatusCard(info),
                const SizedBox(height: Tk.spacing24),
                _buildActionSection(context, info, faceEnrolled),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildGreetingCard(String nama, String? jabatan, String tanggal) {
    return Container(
      padding: const EdgeInsets.all(Tk.spacing16),
      decoration: BoxDecoration(
        color: Tk.navy,
        borderRadius: BorderRadius.circular(Tk.radiusCard),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Halo, $nama',
            style: const TextStyle(
              color: Tk.onPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (jabatan != null && jabatan.isNotEmpty) ...[
            const SizedBox(height: Tk.spacing4),
            Text(
              jabatan,
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ],
          const SizedBox(height: Tk.spacing12),
          Text(
            'Tanggal Server: $tanggal',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleCard(TodayAttendanceInfo info) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Tk.spacing16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Jadwal Hari Ini',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Tk.navy,
              ),
            ),
            const SizedBox(height: Tk.spacing8),
            if (info.isHoliday)
              const Text(
                'Hari ini merupakan hari libur kantor.',
                style: TextStyle(color: Tk.izinText, fontWeight: FontWeight.w600),
              )
            else if (!info.hasSchedule || info.shift == null)
              const Text(
                'Tidak ada jadwal kerja pada hari ini.',
                style: TextStyle(color: Tk.textMuted),
              )
            else ...[
              Text(
                'Shift ${info.shift!.nama}',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
              ),
              const SizedBox(height: Tk.spacing4),
              Text(
                'Jam Kerja: ${info.shift!.jamMasuk} – ${info.shift!.jamPulang} WIB (Toleransi ${info.shift!.toleransiMenit} menit)',
                style: const TextStyle(color: Tk.textMuted, fontSize: 13),
              ),
            ],
            if (info.locations.isNotEmpty) ...[
              const Divider(height: Tk.spacing24, color: Tk.outline),
              Text(
                'Lokasi Kantor Aktif: ${info.locations.map((e) => '${e.nama} (${e.radiusMeter}m)').join(', ')}',
                style: const TextStyle(fontSize: 12, color: Tk.textMuted),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAttendanceStatusCard(TodayAttendanceInfo info) {
    final att = info.attendance;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Tk.spacing16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Status Kehadiran Hari Ini',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Tk.navy,
                  ),
                ),
                StatusBadge(status: att?.status ?? 'menunggu'),
              ],
            ),
            const SizedBox(height: Tk.spacing12),
            Row(
              children: [
                Expanded(
                  child: _buildTimeBox('Jam Masuk', att?.jamMasuk ?? '--:--:--'),
                ),
                const SizedBox(width: Tk.spacing12),
                Expanded(
                  child: _buildTimeBox('Jam Pulang', att?.jamPulang ?? '--:--:--'),
                ),
              ],
            ),
            if (att?.lokasi != null) ...[
              const SizedBox(height: Tk.spacing8),
              Text(
                'Lokasi tercatat: ${att!.lokasi}',
                style: const TextStyle(fontSize: 13, color: Tk.textMuted),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTimeBox(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(Tk.spacing12),
      decoration: BoxDecoration(
        color: Tk.surfaceTint,
        borderRadius: BorderRadius.circular(Tk.radiusInput),
        border: Border.all(color: Tk.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Tk.textMuted)),
          const SizedBox(height: Tk.spacing4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Tk.navy,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionSection(
    BuildContext context,
    TodayAttendanceInfo info,
    bool faceEnrolled,
  ) {
    if (!faceEnrolled) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(Tk.spacing12),
            decoration: BoxDecoration(
              color: Tk.terlambatBg,
              borderRadius: BorderRadius.circular(Tk.radiusInput),
            ),
            child: const Text(
              'Wajah Anda belum terdaftar. Lakukan registrasi wajah terlebih dahulu untuk membuka menu absensi.',
              style: TextStyle(color: Tk.terlambatText, fontSize: 13),
            ),
          ),
          const SizedBox(height: Tk.spacing12),
          PrimaryButton(
            text: 'Registrasi Wajah',
            icon: Icons.face_retouching_natural,
            onPressed: () => context.push('/face/enroll'),
          ),
        ],
      );
    }

    if (info.canCheckIn) {
      return PrimaryButton(
        text: 'Absen Masuk',
        icon: Icons.login,
        onPressed: () => context.push('/attendance/capture?mode=check-in'),
      );
    }

    if (info.canCheckOut) {
      return PrimaryButton(
        text: 'Absen Pulang',
        icon: Icons.logout,
        backgroundColor: Tk.navy,
        onPressed: () => context.push('/attendance/capture?mode=check-out'),
      );
    }

    return PrimaryButton(
      text: info.isHoliday
          ? 'Hari Libur'
          : (!info.hasSchedule ? 'Tidak Ada Jadwal' : 'Absensi Hari Ini Selesai'),
      icon: Icons.check_circle_outline,
      onPressed: null,
    );
  }
}
