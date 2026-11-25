import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../design/tokens.dart';
import '../../../../design/widgets/primary_button.dart';
import '../cubit/leave_cubit.dart';

class LeaveFormPage extends StatefulWidget {
  const LeaveFormPage({super.key});

  @override
  State<LeaveFormPage> createState() => _LeaveFormPageState();
}

class _LeaveFormPageState extends State<LeaveFormPage> {
  final _formKey = GlobalKey<FormState>();
  String _jenis = 'izin';
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now();
  final _alasanController = TextEditingController();
  final _lampiranPathController = TextEditingController();

  @override
  void dispose() {
    _alasanController.dispose();
    _lampiranPathController.dispose();
    super.dispose();
  }

  String _formatDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _pickDate({required bool isStart}) async {
    final initial = isStart ? _startDate : _endDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2024),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
          if (_endDate.isBefore(_startDate)) {
            _endDate = _startDate;
          }
        } else {
          _endDate = picked;
        }
      });
    }
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    final attachment = _lampiranPathController.text.trim();
    context.read<LeaveCubit>().submitLeave(
          jenis: _jenis,
          tanggalMulai: _formatDate(_startDate),
          tanggalSelesai: _formatDate(_endDate),
          alasan: _alasanController.text.trim(),
          attachmentPath: attachment.isEmpty ? null : attachment,
        );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<LeaveCubit, LeaveState>(
      listener: (context, state) {
        if (state is LeaveSubmitSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Pengajuan izin berhasil dikirim.')),
          );
          context.pop(true);
        } else if (state is LeaveFailure) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: Tk.alpaText,
              content: Text(state.failure.message),
            ),
          );
        }
      },
      builder: (context, state) {
        final isSubmitting = state is LeaveSubmitting;

        return Scaffold(
          appBar: AppBar(title: const Text('Ajukan Izin / Cuti')),
          body: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(Tk.spacing16),
              children: [
                const Text(
                  'Jenis Pengajuan',
                  style: TextStyle(fontWeight: FontWeight.w600, color: Tk.navy),
                ),
                const SizedBox(height: Tk.spacing8),
                DropdownButtonFormField<String>(
                  initialValue: _jenis,
                  items: const [
                    DropdownMenuItem(value: 'izin', child: Text('Izin')),
                    DropdownMenuItem(value: 'sakit', child: Text('Sakit')),
                    DropdownMenuItem(value: 'cuti', child: Text('Cuti')),
                  ],
                  onChanged: isSubmitting
                      ? null
                      : (v) => setState(() => _jenis = v ?? 'izin'),
                ),
                const SizedBox(height: Tk.spacing16),
                Row(
                  children: [
                    Expanded(
                      child: _dateTile(
                        label: 'Tanggal Mulai',
                        value: _formatDate(_startDate),
                        onTap: isSubmitting ? null : () => _pickDate(isStart: true),
                      ),
                    ),
                    const SizedBox(width: Tk.spacing12),
                    Expanded(
                      child: _dateTile(
                        label: 'Tanggal Selesai',
                        value: _formatDate(_endDate),
                        onTap: isSubmitting ? null : () => _pickDate(isStart: false),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: Tk.spacing16),
                TextFormField(
                  controller: _alasanController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Alasan Pengajuan',
                    hintText: 'Tuliskan alasan izin/sakit/cuti secara singkat',
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Alasan wajib diisi.'
                      : null,
                ),
                const SizedBox(height: Tk.spacing16),
                TextFormField(
                  controller: _lampiranPathController,
                  decoration: const InputDecoration(
                    labelText: 'Path Berkas Lampiran (Opsional)',
                    hintText: 'Contoh: /storage/.../surat_dokter.pdf',
                    prefixIcon: Icon(Icons.attach_file),
                  ),
                ),
                const SizedBox(height: Tk.spacing24),
                PrimaryButton(
                  text: 'Kirim Pengajuan',
                  icon: Icons.send,
                  isLoading: isSubmitting,
                  onPressed: _submit,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _dateTile({
    required String label,
    required String value,
    required VoidCallback? onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(Tk.radiusInput),
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: Tk.minTouchTarget),
        padding: const EdgeInsets.all(Tk.spacing12),
        decoration: BoxDecoration(
          color: Tk.surface,
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
                fontWeight: FontWeight.w700,
                color: Tk.navy,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
