import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../design/tokens.dart';
import '../../../../design/widgets/primary_button.dart';
import '../../../../design/widgets/status_badge.dart';
import '../../domain/entities/attendance_entities.dart';
import '../cubit/history_cubit.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  late DateTime _selectedMonth;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedMonth = DateTime(now.year, now.month);
    _fetchMonth();
  }

  String get _monthQuery =>
      '${_selectedMonth.year.toString().padLeft(4, '0')}-${_selectedMonth.month.toString().padLeft(2, '0')}';

  void _fetchMonth() {
    context.read<HistoryCubit>().loadHistory(month: _monthQuery);
  }

  void _shiftMonth(int delta) {
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + delta);
    });
    _fetchMonth();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Riwayat Kehadiran')),
      body: Column(
        children: [
          Container(
            color: Tk.surface,
            padding: const EdgeInsets.symmetric(
              horizontal: Tk.spacing12,
              vertical: Tk.spacing8,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  tooltip: 'Bulan Sebelumnya',
                  constraints: const BoxConstraints(
                    minWidth: Tk.minTouchTarget,
                    minHeight: Tk.minTouchTarget,
                  ),
                  onPressed: () => _shiftMonth(-1),
                  icon: const Icon(Icons.chevron_left),
                ),
                Text(
                  'Periode $_monthQuery',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Tk.navy,
                  ),
                ),
                IconButton(
                  tooltip: 'Bulan Berikutnya',
                  constraints: const BoxConstraints(
                    minWidth: Tk.minTouchTarget,
                    minHeight: Tk.minTouchTarget,
                  ),
                  onPressed: () => _shiftMonth(1),
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Tk.outline),
          Expanded(
            child: BlocBuilder<HistoryCubit, HistoryState>(
              builder: (context, state) {
                if (state is HistoryLoading || state is HistoryInitial) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (state is HistoryFailure) {
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
                          text: 'Muat Ulang',
                          onPressed: _fetchMonth,
                        ),
                      ],
                    ),
                  );
                }

                final history = (state as HistorySuccess).history;
                return RefreshIndicator(
                  onRefresh: () async => _fetchMonth(),
                  child: ListView(
                    padding: const EdgeInsets.all(Tk.spacing16),
                    children: [
                      _buildSummaryGrid(history.summary),
                      const SizedBox(height: Tk.spacing16),
                      if (history.items.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: Tk.spacing32),
                          child: Center(
                            child: Text(
                              'Belum ada riwayat kehadiran pada periode ini.',
                              style: TextStyle(color: Tk.textMuted),
                            ),
                          ),
                        )
                      else
                        ...history.items.map(_buildHistoryTile),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryGrid(MonthlySummary s) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Tk.spacing12),
        child: Wrap(
          spacing: Tk.spacing8,
          runSpacing: Tk.spacing8,
          children: [
            _summaryChip('Hadir', s.hadir, Tk.hadirBg, Tk.hadirText),
            _summaryChip('Terlambat', s.terlambat, Tk.terlambatBg, Tk.terlambatText),
            _summaryChip('Izin', s.izin, Tk.izinBg, Tk.izinText),
            _summaryChip('Sakit', s.sakit, Tk.izinBg, Tk.izinText),
            _summaryChip('Cuti', s.cuti, Tk.izinBg, Tk.izinText),
            _summaryChip('Alpa', s.alpa, Tk.alpaBg, Tk.alpaText),
          ],
        ),
      ),
    );
  }

  Widget _summaryChip(String label, int count, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(Tk.radiusInput),
      ),
      child: Text(
        '$label: $count',
        style: TextStyle(color: fg, fontWeight: FontWeight.w700, fontSize: 13),
      ),
    );
  }

  Widget _buildHistoryTile(AttendanceRecord item) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Tk.spacing8),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(Tk.spacing12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    item.tanggal,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: Tk.navy,
                    ),
                  ),
                  StatusBadge(status: item.status),
                ],
              ),
              const SizedBox(height: Tk.spacing8),
              Text(
                'Masuk: ${item.jamMasuk ?? '-'}   •   Pulang: ${item.jamPulang ?? '-'}',
                style: const TextStyle(fontSize: 13, color: Tk.navy),
              ),
              if (item.lokasi != null) ...[
                const SizedBox(height: Tk.spacing4),
                Text(
                  'Lokasi: ${item.lokasi}',
                  style: const TextStyle(fontSize: 12, color: Tk.textMuted),
                ),
              ],
              if (item.keterangan != null && item.keterangan!.isNotEmpty) ...[
                const SizedBox(height: Tk.spacing4),
                Text(
                  'Keterangan: ${item.keterangan}',
                  style: const TextStyle(fontSize: 12, color: Tk.textMuted),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
