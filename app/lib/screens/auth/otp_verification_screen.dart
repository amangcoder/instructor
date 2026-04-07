/// OtpVerificationScreen — 6-digit OTP entry to complete login.
library otp_verification_screen;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:instructor/providers/auth_providers.dart';
import 'package:instructor/router.dart';
import 'package:instructor/services/auth_service.dart';
import 'widgets/countdown_timer.dart';
import 'widgets/otp_input_field.dart';

/// Second step of the email+OTP authentication flow.
///
/// Receives [email] from [LoginScreen] via go_router's `extra` parameter.
/// Shows a 6-digit OTP input with a 5-minute countdown, Verify and
/// Resend OTP buttons.
class OtpVerificationScreen extends ConsumerStatefulWidget {
  const OtpVerificationScreen({
    super.key,
    required this.email,
  });

  final String email;

  @override
  ConsumerState<OtpVerificationScreen> createState() =>
      _OtpVerificationScreenState();
}

class _OtpVerificationScreenState
    extends ConsumerState<OtpVerificationScreen> {
  static const Duration _otpValidDuration = Duration(minutes: 5);

  final _otpFieldKey = GlobalKey<OtpInputFieldState>();

  String _currentOtp = '';
  bool _isVerifying = false;
  bool _isResending = false;
  bool _otpExpired = false;
  String? _errorMessage;

  /// Tracks the OTP validity window — reset on every resend.
  Duration _timerDuration = _otpValidDuration;

  Future<void> _verify() async {
    if (_currentOtp.length != 6) {
      setState(() => _errorMessage = 'Please enter all 6 digits.');
      return;
    }
    if (_otpExpired) {
      setState(() =>
          _errorMessage = 'Your OTP has expired. Please request a new one.');
      return;
    }

    setState(() {
      _isVerifying = true;
      _errorMessage = null;
    });

    HapticFeedback.lightImpact();

    try {
      final authService = ref.read(authServiceProvider);
      final result = await authService.verifyOtp(widget.email, _currentOtp);

      // Update the auth state provider.
      await ref.read(authStateNotifierProvider.notifier).onLoginSuccess(result);

      if (mounted) {
        // Navigate home and clear the auth navigation stack.
        context.go(AppRoutes.library);
      }
    } on AuthException catch (e) {
      HapticFeedback.mediumImpact();
      if (mounted) {
        setState(() => _errorMessage = e.userMessage);
        _otpFieldKey.currentState?.clear();
        _currentOtp = '';
      }
    } catch (e) {
      HapticFeedback.mediumImpact();
      if (mounted) {
        setState(() =>
            _errorMessage = 'Verification failed. Please try again.');
        _otpFieldKey.currentState?.clear();
        _currentOtp = '';
      }
    } finally {
      if (mounted) {
        setState(() => _isVerifying = false);
      }
    }
  }

  Future<void> _resendOtp() async {
    setState(() {
      _isResending = true;
      _errorMessage = null;
      _otpExpired = false;
    });

    HapticFeedback.lightImpact();

    try {
      final authService = ref.read(authServiceProvider);
      await authService.requestOtp(widget.email);

      if (mounted) {
        // Reset the countdown by giving CountdownTimer a new duration object.
        setState(() {
          _timerDuration =
              _otpValidDuration + const Duration(microseconds: 1);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('A new OTP has been sent.')),
        );
        _otpFieldKey.currentState?.clear();
        _currentOtp = '';
      }
    } on AuthException catch (e) {
      if (mounted) {
        setState(() => _errorMessage = e.userMessage);
      }
    } catch (e) {
      if (mounted) {
        setState(
            () => _errorMessage = 'Could not resend OTP. Please try again.');
      }
    } finally {
      if (mounted) {
        setState(() => _isResending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isBusy = _isVerifying || _isResending;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Verify OTP'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding:
                const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Header ───────────────────────────────────────────────
                  Icon(
                    Icons.mark_email_unread_outlined,
                    size: 64,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Check your email',
                    style: theme.textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  RichText(
                    textAlign: TextAlign.center,
                    text: TextSpan(
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                      children: [
                        const TextSpan(text: 'We sent a 6-digit code to '),
                        TextSpan(
                          text: widget.email,
                          style: TextStyle(
                            color: colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 40),

                  // ── OTP input ────────────────────────────────────────────
                  OtpInputField(
                    key: _otpFieldKey,
                    enabled: !isBusy && !_otpExpired,
                    onCompleted: (otp) {
                      setState(() => _currentOtp = otp);
                      _verify();
                    },
                    onChanged: (value) =>
                        setState(() => _currentOtp = value),
                  ),

                  const SizedBox(height: 16),

                  // ── Countdown ────────────────────────────────────────────
                  Center(
                    child: CountdownTimer(
                      duration: _timerDuration,
                      onExpired: () => setState(() => _otpExpired = true),
                    ),
                  ),

                  // ── Error message ────────────────────────────────────────
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      _errorMessage!,
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: colorScheme.error),
                      textAlign: TextAlign.center,
                    ),
                  ],

                  const SizedBox(height: 24),

                  // ── Verify button ────────────────────────────────────────
                  FilledButton(
                    onPressed: (isBusy || _otpExpired) ? null : _verify,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isVerifying
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child:
                                CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Verify',
                            style: TextStyle(fontSize: 16)),
                  ),

                  const SizedBox(height: 12),

                  // ── Resend OTP button ────────────────────────────────────
                  OutlinedButton(
                    onPressed: isBusy ? null : _resendOtp,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isResending
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child:
                                CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Resend OTP'),
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
