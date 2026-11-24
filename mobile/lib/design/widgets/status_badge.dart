import 'package:flutter/material.dart';
import '../tokens.dart';

class StatusBadge extends StatelessWidget {
  final String status;

  const StatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    Color textColor;
    Color bgColor;

    switch (status.toLowerCase()) {
      case 'hadir':
        textColor = Tk.hadirText;
        bgColor = Tk.hadirBg;
        break;
      case 'terlambat':
        textColor = Tk.terlambatText;
        bgColor = Tk.terlambatBg;
        break;
      case 'izin':
      case 'sakit':
      case 'cuti':
      case 'disetujui':
        textColor = Tk.izinText;
        bgColor = Tk.izinBg;
        break;
      case 'alpa':
      case 'ditolak':
      case 'gagal':
        textColor = Tk.alpaText;
        bgColor = Tk.alpaBg;
        break;
      case 'menunggu':
      default:
        textColor = Tk.menungguText;
        bgColor = Tk.menungguBg;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(Tk.radiusChip),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: textColor,
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
