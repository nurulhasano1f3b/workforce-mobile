import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/providers.dart';
import 'home_screen.dart';

/// Full login screen — replaces the prototype auto-login gate.
///
/// On success the app navigates to HomeScreen (replacing this route).
/// The JWT is stored in flutter_secure_storage by PunchRepository.login().
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();

  bool _obscure = true;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    final repo = ref.read(punchRepositoryProvider);
    final ok = await repo.login(
      _emailCtrl.text.trim(),
      _passCtrl.text,
    );

    if (!mounted) return;
    setState(() => _loading = false);

    if (ok) {
      // Notify other repositories of the new token then navigate.
      ref.read(shiftsRepositoryProvider).updateToken(repo.token);
      ref.read(notificationsRepositoryProvider).updateToken(repo.token);
      ref.read(userRepositoryProvider).updateToken(repo.token);

      unawaited(
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        ),
      );
    } else {
      setState(() => _error = 'Invalid email or password.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Logo / branding
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1B8A5A),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF1B8A5A).withAlpha(80),
                          blurRadius: 20,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.access_time_rounded,
                      size: 40,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Workforce',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF111827),
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Sign in to your account',
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                  const SizedBox(height: 40),

                  // Email field
                  TextFormField(
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    autocorrect: false,
                    decoration: _inputDecoration(
                      label: 'Email address',
                      icon: Icons.email_outlined,
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Email is required';
                      }
                      if (!v.contains('@')) return 'Enter a valid email';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Password field
                  TextFormField(
                    controller: _passCtrl,
                    obscureText: _obscure,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _submit(),
                    decoration: _inputDecoration(
                      label: 'Password',
                      icon: Icons.lock_outline_rounded,
                      suffix: IconButton(
                        icon: Icon(
                          _obscure
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          size: 20,
                          color: const Color(0xFF9CA3AF),
                        ),
                        onPressed: () =>
                            setState(() => _obscure = !_obscure),
                      ),
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Password is required';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),

                  // Error message
                  if (_error != null) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEE2E2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: const Color(0xFFFCA5A5)),
                      ),
                      child: Text(
                        _error!,
                        style: const TextStyle(
                          color: Color(0xFFB91C1C),
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  const SizedBox(height: 8),

                  // Sign in button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1B8A5A),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        disabledBackgroundColor:
                            const Color(0xFF1B8A5A).withAlpha(120),
                      ),
                      child: _loading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Sign In',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                    ),
                  ),

                  const SizedBox(height: 32),
                  const Text(
                    'Use your store email and password.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF9CA3AF),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
    Widget? suffix,
  }) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, size: 20, color: const Color(0xFF9CA3AF)),
      suffixIcon: suffix,
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide:
            const BorderSide(color: Color(0xFF1B8A5A), width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFF87171)),
      ),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }
}
