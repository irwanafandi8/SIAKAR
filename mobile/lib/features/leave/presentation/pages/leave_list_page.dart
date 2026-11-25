import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../design/tokens.dart';
import '../../../../design/widgets/primary_button.dart';
import '../../../../design/widgets/status_badge.dart';
import '../../domain/entities/leave_entities.dart';
import '../cubit/leave_cubit.dart';

class LeaveListPage extends StatefulWidget {
  const LeaveListPage({super.key});

  @override
  State<LeaveListPage> createState() => _LeaveListPageState();
}

class _LeaveListPageState extends State<LeaveListPage> {
  String? _selectedStatus;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    context.read<LeaveCubit>().loadLeaves(status: _selectedStatus);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pengajuan Izin')),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Tk.primary,
        foregroundColor: Tk.onPrimary,
        onPressed: () async {
          final created = await context.push<bool>('/leave/new');
          if (created == true && mounted) {
            _load();
          }
        },
        icon: const Icon(Icons.add),
        label: const Text('Ajukan Izin'),
      ),
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
                _filterChip('Semua', null),
                const SizedBox(width: Tk.spacing8),
                _filterChip('Menunggu', 'menunggu'),
                const SizedBox(width: Tk.spacing8),
                _filterChip('Disetujui', 'disetujui'),
                const SizedBox(width: Tk.spacing8),
                _filterChip('Ditolak', 'ditolak'),
              ],
            ),
          ),
          const Divider(height: 1, color: Tk.outline),
          Expanded(
            child: BlocBuilder<LeaveCubit, LeaveState>(
              builder: (context, state) {
                if (state is LeaveLoading || state is LeaveInitial) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (state is LeaveFailure) {
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

                if (state is! LeaveLoaded) {
                  return const SizedBox.shrink();
                }

                if (state.items.isEmpty) {
                  return const Center(
                    child: Text(
                      'Belum ada pengajuan izin.',
                      style: TextStyle(color: Tk.textMuted),
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async => _load(),
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(
                      Tk.spacing16,
                      Tk.spacing16,
                      Tk.spacing16,
                      88,
                    ),
                    itemCount: state.items.length,
                    itemBuilder: (context, index) =>
                        _buildLeaveCard(state.items[index]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String label, String? statusValue) {
    final selected = _selectedStatus == statusValue;
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
          setState(() => _selectedStatus = statusValue);
          _load();
        },
      ),
    );
  }

  Widget _buildLeaveCard(LeaveRequestEntity item) {
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
                  Text(
                    item.jenis.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Tk.navy,
                    ),
                  ),
                  StatusBadge(status: item.status),
                ],
              ),
              const SizedBox(height: Tk.spacing8),
              Text(
                '${item.tanggalMulai} s.d. ${item.tanggalSelesai}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Tk.navy,
                ),
              ),
              const SizedBox(height: Tk.spacing4),
              Text(
                item.alasan,
                style: const TextStyle(fontSize: 13, color: Tk.textMuted),
              ),
              if (item.lampiranUrl != null) ...[
                const SizedBox(height: Tk.spacing8),
                const Row(
                  children: [
                    Icon(Icons.attach_file, size: 16, color: Tk.primary),
                    SizedBox(width: 4),
                    Text(
                      'Lampiran tersedia',
                      style: TextStyle(fontSize: 12, color: Tk.primary),
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
