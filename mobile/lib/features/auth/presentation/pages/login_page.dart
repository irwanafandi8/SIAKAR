import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../design/tokens.dart';
import '../../../../design/widgets/primary_button.dart';
import '../cubit/auth_cubit.dart';
import '../cubit/auth_state.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _onLoginPressed() {
    if (_formKey.currentState?.validate() ?? false) {
      // Gunakan ID perangkat sementara untuk Android/demo
      const deviceId = 'android_device_demo_001';

      context.read<AuthCubit>().login(
            username: _usernameController.text.trim(),
            password: _passwordController.text,
            deviceId: deviceId,
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Tk.background,
      body: BlocConsumer<AuthCubit, AuthState>(
        listener: (context, state) {
          if (state is Authenticated) {
            context.go('/home');
          } else if (state is AuthFailureState) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Tk.alpaText,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        },
        builder: (context, state) {
          final isLoading = state is AuthLoading;

          return SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Logo & Judul
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: Tk.navy,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Icon(
                          Icons.face_retouching_natural_rounded,
                          size: 48,
                          color: Tk.primary,
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'SIAKAR',
                        style: TextStyle(
                          color: Tk.navy,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Sistem Absensi Karyawan Berbasis Pengenalan Wajah',
                        style: TextStyle(
                          color: Tk.textMuted,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 36),

                      // Card Form
                      Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(Tk.radiusCard),
                          side: const BorderSide(color: Tk.outline),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Masuk ke Akun',
                                style: TextStyle(
                                  color: Tk.navy,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 20),

                              // Input Username
                              TextFormField(
                                controller: _usernameController,
                                decoration: const InputDecoration(
                                  labelText: 'Username',
                                  prefixIcon: Icon(Icons.person_outline, color: Tk.textMuted),
                                ),
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Harap masukkan username Anda';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),

                              // Input Password
                              TextFormField(
                                controller: _passwordController,
                                obscureText: _obscurePassword,
                                decoration: InputDecoration(
                                  labelText: 'Kata Sandi',
                                  prefixIcon: const Icon(Icons.lock_outline, color: Tk.textMuted),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscurePassword
                                          ? Icons.visibility_outlined
                                          : Icons.visibility_off_outlined,
                                      color: Tk.textMuted,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _obscurePassword = !_obscurePassword;
                                      });
                                    },
                                  ),
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Harap masukkan kata sandi';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 24),

                              // Tombol Masuk
                              PrimaryButton(
                                text: 'Masuk',
                                onPressed: _onLoginPressed,
                                isLoading: isLoading,
                                icon: Icons.login_rounded,
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),
                      const Center(
                        child: Text(
                          'SIAKAR v1.0.0 — D4 Rekayasa Perangkat Lunak',
                          style: TextStyle(
                            color: Tk.textMuted,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
