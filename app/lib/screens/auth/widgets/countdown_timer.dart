/// CountdownTimer — animated countdown display for OTP validity window.
library countdown_timer;

import 'dart:async';

import 'package:flutter/material.dart';

/// Displays a self-ticking countdown in MM:SS format.
///
/// Calls [onExpired] when the timer reaches zero. Re-creates the internal
/// [Timer] whenever [duration] changes so the parent can restart the countdown
/// (e.g. after a resend-OTP action) without re-creating the widget.
class CountdownTimer extends StatefulWidget {
  const CountdownTimer({
    super.key,
    required this.duration,
    this.onExpired,
    this.style,
    this.expiredText = 'OTP expired',
  });

  /// Total countdown duration (e.g. `Duration(minutes: 5)`).
  final Duration duration;

  /// Called exactly once when the timer reaches zero.
  final VoidCallback? onExpired;

  /// Optional text style for the countdown display.
  final TextStyle? style;

  /// Text shown after the timer expires.
  final String expiredText;

  @override
  State<CountdownTimer> createState() => _CountdownTimerState();
}

class _CountdownTimerState extends State<CountdownTimer> {
  late Duration _remaining;
  Timer? _ticker;
  bool _expired = false;

  @override
  void initState() {
    super.initState();
    _start(widget.duration);
  }

  @override
  void didUpdateWidget(CountdownTimer oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Restart if the parent provides a new duration (e.g. OTP resent).
    if (oldWidget.duration != widget.duration) {
      _ticker?.cancel();
      _expired = false;
      _start(widget.duration);
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _start(Duration duration) {
    _remaining = duration;
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        if (_remaining.inSeconds <= 0) {
          _ticker?.cancel();
          _expired = true;
          widget.onExpired?.call();
        } else {
          _remaining -= const Duration(seconds: 1);
        }
      });
    });
  }

  String _format(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    if (_expired) {
      return Text(
        widget.expiredText,
        style: widget.style ??
            TextStyle(color: Theme.of(context).colorScheme.error),
      );
    }

    final color = _remaining.inSeconds <= 30
        ? Theme.of(context).colorScheme.error
        : Theme.of(context).colorScheme.primary;

    return Semantics(
      label: 'OTP expires in ${_remaining.inMinutes} minutes '
          '${_remaining.inSeconds.remainder(60)} seconds',
      child: Text(
        _format(_remaining),
        style: widget.style ?? TextStyle(color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}
