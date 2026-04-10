/// LoginScreen — Stitch "Login - Email Entry" design.
library login_screen;

import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:instructor/router.dart';
import 'package:instructor/services/auth_service.dart';
import 'package:instructor/theme/app_branding.dart';
import 'package:instructor/theme/gradient_button.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  bool _isValidEmail(String email) {
    return email.contains('@') && email.contains('.');
  }

  Future<void> _requestOtp() async {
    final email = _emailController.text.trim();
    if (!_isValidEmail(email)) {
      setState(() => _errorMessage = 'Please enter a valid email address.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    HapticFeedback.lightImpact();

    try {
      final authService = ref.read(authServiceProvider);
      await authService.requestOtp(email);

      if (mounted) {
        context.push(AppRoutes.otpVerification, extra: email);
      }
    } on AuthException catch (e) {
      if (mounted) {
        setState(() => _errorMessage = e.userMessage);
      }
    } catch (e) {
      if (mounted) {
        setState(
            () => _errorMessage = 'Could not send OTP. Check your network connection.');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: Stack(
        children: [
          // ── Atmospheric blur circles (Stitch background) ──────────────
          Positioned(
            top: -96,
            right: -96,
            child: Container(
              width: 256,
              height: 256,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colorScheme.primaryContainer.withValues(alpha: 0.2),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 100, sigmaY: 100),
                child: const SizedBox.expand(),
              ),
            ),
          ),
          Positioned(
            bottom: -96,
            left: -96,
            child: Container(
              width: 256,
              height: 256,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colorScheme.tertiaryContainer.withValues(alpha: 0.2),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 100, sigmaY: 100),
                child: const SizedBox.expand(),
              ),
            ),
          ),

          // ── Main content ──────────────────────────────────────────────
          SafeArea(
            child: Column(
              children: [
                // ── Header: "Instructor" gradient text ──────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: AppBranding.gradientTitle(),
                  ),
                ),

                // ── Scrollable body ─────────────────────────────────────
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 24),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 480),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // ── Hero text ───────────────────────────────
                            Text(
                              'Welcome Back',
                              style: GoogleFonts.manrope(
                                fontSize: 36,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.5,
                                color: colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Enter your email to continue your mastery journey with Instructor.',
                              style: TextStyle(
                                fontSize: 18,
                                color: colorScheme.onSurfaceVariant,
                                height: 1.5,
                              ),
                            ),

                            const SizedBox(height: 48),

                            // ── Form card ───────────────────────────────
                            Container(
                              padding: const EdgeInsets.all(32),
                              decoration: BoxDecoration(
                                color: colorScheme.surfaceContainerLow,
                                borderRadius: BorderRadius.circular(32),
                              ),
                              child: Form(
                                key: _formKey,
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    // Email label
                                    Padding(
                                      padding: const EdgeInsets.only(
                                          left: 4, bottom: 8),
                                      child: Text(
                                        'EMAIL ADDRESS',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          letterSpacing: 1.5,
                                          color:
                                              colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ),
                                    // Email input
                                    Semantics(
                                      label: 'Email address',
                                      child: TextFormField(
                                        controller: _emailController,
                                        enabled: !_isLoading,
                                        keyboardType:
                                            TextInputType.emailAddress,
                                        autocorrect: false,
                                        enableSuggestions: false,
                                        textInputAction:
                                            TextInputAction.done,
                                        onFieldSubmitted: (_) =>
                                            _requestOtp(),
                                        decoration: InputDecoration(
                                          hintText: 'name@example.com',
                                          errorText: _errorMessage,
                                        ),
                                      ),
                                    ),

                                    const SizedBox(height: 32),

                                    // Gradient "Continue" button
                                    GradientButton(
                                      onPressed:
                                          _isLoading ? null : _requestOtp,
                                      height: 56,
                                      borderRadius: 12,
                                      child: _isLoading
                                          ? const SizedBox(
                                              width: 20,
                                              height: 20,
                                              child:
                                                  CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Colors.white,
                                              ),
                                            )
                                          : Row(
                                              mainAxisSize:
                                                  MainAxisSize.min,
                                              children: [
                                                Text(
                                                  'CONTINUE',
                                                  style:
                                                      GoogleFonts.manrope(
                                                    color: colorScheme
                                                        .onPrimary,
                                                    fontWeight:
                                                        FontWeight.w700,
                                                    fontSize: 14,
                                                    letterSpacing: 2,
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Icon(
                                                  Icons.arrow_forward,
                                                  color: colorScheme
                                                      .onPrimary,
                                                  size: 20,
                                                ),
                                              ],
                                            ),
                                    ),

                                    const SizedBox(height: 24),

                                    // Support links
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        TextButton(
                                          onPressed: () {},
                                          child: Text(
                                            'Forgot Password?',
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w500,
                                              color: colorScheme.primary,
                                            ),
                                          ),
                                        ),
                                        TextButton(
                                          onPressed: () {},
                                          child: Text(
                                            'Sign Up',
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w500,
                                              color: colorScheme
                                                  .onSurfaceVariant,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            const SizedBox(height: 32),

                            // ── Bento feature cards ─────────────────────
                            Row(
                              children: [
                                Expanded(
                                  child: _FeatureCard(
                                    icon: Icons.auto_awesome,
                                    text: 'Guided by AI Intelligence',
                                    color:
                                        colorScheme.surfaceContainerHigh,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: _FeatureCard(
                                    icon: Icons.library_books,
                                    text: 'Personalized Library Access',
                                    color: colorScheme.primary
                                        .withValues(alpha: 0.05),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // ── Footer ──────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'By signing in, you agree to our Terms of Service and Privacy Policy.',
                    style: TextStyle(
                      fontSize: 12,
                      color: colorScheme.outlineVariant,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({
    required this.icon,
    required this.text,
    required this.color,
  });

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return AspectRatio(
      aspectRatio: 4 / 3,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(icon, color: colorScheme.primary, size: 30),
            Text(
              text,
              style: GoogleFonts.manrope(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
