import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../design/tokens.dart';
import '../../../../design/widgets/primary_button.dart';

class PlaceholderFeaturePage extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;

  const PlaceholderFeaturePage({
    super.key,
    required this.title,
    required this.description,
    this.icon = Icons.camera_alt_outlined,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Padding(
        padding: const EdgeInsets.all(Tk.spacing24),
        child: Center(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(Tk.spacing24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 56, color: Tk.primary),
                  const SizedBox(height: Tk.spacing16),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Tk.navy,
                    ),
                  ),
                  const SizedBox(height: Tk.spacing8),
                  Text(
                    description,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Tk.textMuted, fontSize: 14),
                  ),
                  const SizedBox(height: Tk.spacing24),
                  PrimaryButton(
                    text: 'Kembali',
                    onPressed: () {
                      if (context.canPop()) {
                        context.pop();
                      } else {
                        context.go('/home');
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
