import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../design/tokens.dart';
import '../../../../design/widgets/primary_button.dart';
import '../../../../design/widgets/status_badge.dart';
import '../../../leave/domain/entities/leave_entities.dart';
import '../../domain/entities/team_recap_entity.dart';
import '../cubit/approval_cubits.dart';

class ApprovalListPage extends StatefulWidget {
  const ApprovalListPage({super.key});

  @override
  State<ApprovalListPage> createState() => _ApprovalListPageState();
}

class _ApprovalListPageState extends State<ApprovalListPage> {
  String _status = 'menunggu';

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    context.read<ApprovalCubit>().loadApprovals(status: _status);
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ApprovalCubit, ApprovalState>(
      listener: (context, state) {
        if (state is ApprovalLoaded && state.actionMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.actionMessage!)),
          );
        } else if (state is ApprovalFailure) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: Tk.alpaText,
              content: Text(state.failure.message),
            ),
          );
        }
      },
      builder: (context, state) {
        return Scaffold(
          appBar: AppBar(title: const Text('Persetujuan Izin Bawahan')),
          body: Column(
            children: [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                  horizontal: Tk.spacing12,
                  vertical: Tk.spacing8,
                ),
                child: Row(
                  children: [
                    _statusTab('Menunggu', 'menunggu'),
                    const SizedBox(width: Tk.spacing8),
                    _statusTab('Disetujui', 'disetujui'),
                    const SizedBox(width: Tk.spacing8),
                    _statusTab('Ditolak', 'ditolak'),
                  ],
                ),
              ),
              const Divider(height: 1, color: Tk.outline),
              Expanded(child: _buildBody(state)),
            ],
          ),
        );
      },
    );
  }

  Widget _statusTab(String label, String val) {
    final selected = _status == val;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: Tk.minTouchTarget),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        selectedColor: Tk.primary,
        labelStyle: TextStyle(
          color: selected ? Tk.onPrimary : Tk.navy,
          fontWeight: FontWeight.w600,
        ),
        onSelected: (_) {
          setState(() => _status = val);
          _load();
        },
      ),
    );
  }

  Widget _buildBody(ApprovalState state) {
    if (state is ApprovalLoading || state is ApprovalInitial) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state is ApprovalFailure) {
      return Padding(
        padding: const EdgeInsets.all(Tk.spacing24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(state.failure.message, textAlign: TextAlign.center),
            const SizedBox(height: Tk.spacing16),
            PrimaryButton(text: 'Coba Lagi', onPressed: _load),
          ],
        ),
      );
    }

    final loaded = state as ApprovalLoaded;
    if (loaded.items.isEmpty) {
      return const Center(
        child: Text(
          'Tidak ada pengajuan pada kategori ini.',
          style: TextStyle(color: Tk.textMuted),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async => _load(),
      child: ListView.builder(
        padding: const EdgeInsets.all(Tk.spacing16),
        itemCount: loaded.items.length,
        itemBuilder: (context, idx) => _buildApprovalCard(loaded.items[idx]),
      ),
    );
  }

  Widget _buildApprovalCard(LeaveRequestEntity item) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Tk.spacing12),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(Tk.spacing16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      item.pemohon.nama,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Tk.navy,
                      ),
                    ),
                  ),
                  StatusBadge(status: item.status),
                ],
              ),
              const SizedBox(height: Tk.spacing4),
              Text(
                '${item.jenis.toUpperCase()} • ${item.tanggalMulai} s.d. ${item.tanggalSelesai}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Tk.primaryDark,
                ),
              ),
              const SizedBox(height: Tk.spacing8),
              Text(
                item.alasan,
                style: const TextStyle(fontSize: 13, color: Tk.textMuted),
              ),
              if (item.isPending) ...[
                const SizedBox(height: Tk.spacing16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Tk.alpaText,
                          side: const BorderSide(color: Tk.alpaText),
                          minimumSize:
                              const Size(double.infinity, Tk.minTouchTarget),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(Tk.radiusButton),
                          ),
                        ),
                        onPressed: () => context.read<ApprovalCubit>().decide(
                              idIzin: item.idIzin,
                              approve: false,
                              currentStatus: _status,
                            ),
                        child: const Text('Tolak'),
                      ),
                    ),
                    const SizedBox(width: Tk.spacing12),
                    Expanded(
                      child: PrimaryButton(
                        text: 'Setujui',
                        onPressed: () => context.read<ApprovalCubit>().decide(
                              idIzin: item.idIzin,
                              approve: true,
                              currentStatus: _status,
                            ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class TeamRecapPage extends StatefulWidget {
  const TeamRecapPage({super.key});

  @override
  State<TeamRecapPage> createState() => _TeamRecapPageState();
}

class _TeamRecapPageState extends State<TeamRecapPage> {
  late DateTime _from;
  late DateTime _to;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _from = DateTime(now.year, now.month, 1);
    _to = DateTime(now.year, now.month + 1, 0);
    _load();
  }

  String _fmt(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  void _load() {
    context.read<TeamRecapCubit>().loadRecap(from: _fmt(_from), to: _fmt(_to));
  }

  Future<void> _selectRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: DateTime(2030),
      initialDateRange: DateTimeRange(start: _from, end: _to),
    );
    if (picked != null) {
      setState(() {
        _from = picked.start;
        _to = picked.end;
      });
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Rekap Kehadiran Bawahan')),
      body: Column(
        children: [
          Container(
            color: Tk.surface,
            padding: const EdgeInsets.all(Tk.spacing12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${_fmt(_from)} s.d. ${_fmt(_to)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Tk.navy,
                  ),
                ),
                TextButton.icon(
                  style: TextButton.styleFrom(
                    minimumSize: const Size(Tk.minTouchTarget, Tk.minTouchTarget),
                  ),
                  onPressed: _selectRange,
                  icon: const Icon(Icons.date_range),
                  label: const Text('Ubah Periode'),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Tk.outline),
          Expanded(
            child: BlocBuilder<TeamRecapCubit, TeamRecapState>(
              builder: (context, state) {
                if (state is TeamRecapLoading || state is TeamRecapInitial) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (state is TeamRecapFailure) {
                  return Padding(
                    padding: const EdgeInsets.all(Tk.spacing24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(state.failure.message, textAlign: TextAlign.center),
                        const SizedBox(height: Tk.spacing16),
                        PrimaryButton(text: 'Coba Lagi', onPressed: _load),
                      ],
                    ),
                  );
                }

                final success = state as TeamRecapSuccess;
                if (success.items.isEmpty) {
                  return const Center(
                    child: Text(
                      'Belum ada data bawahan langsung.',
                      style: TextStyle(color: Tk.textMuted),
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async => _load(),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(Tk.spacing16),
                    itemCount: success.items.length,
                    itemBuilder: (context, idx) =>
                        _buildRecapCard(success.items[idx]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecapCard(SubordinateRecapItem item) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Tk.spacing12),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(Tk.spacing16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.nama,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Tk.navy,
                ),
              ),
              const SizedBox(height: Tk.spacing12),
              Wrap(
                spacing: Tk.spacing8,
                runSpacing: Tk.spacing8,
                children: [
                  _badge('Hadir', item.hadir, Tk.hadirBg, Tk.hadirText),
                  _badge('Terlambat', item.terlambat, Tk.terlambatBg, Tk.terlambatText),
                  _badge('Izin', item.izin, Tk.izinBg, Tk.izinText),
                  _badge('Sakit', item.sakit, Tk.izinBg, Tk.izinText),
                  _badge('Cuti', item.cuti, Tk.izinBg, Tk.izinText),
                  _badge('Alpa', item.alpa, Tk.alpaBg, Tk.alpaText),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _badge(String label, int val, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(Tk.radiusInput),
      ),
      child: Text(
        '$label: $val',
        style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w700),
      ),
    );
  }
}
