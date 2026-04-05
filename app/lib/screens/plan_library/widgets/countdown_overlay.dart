import 'package:flutter/material.dart';

/// Shows a full-screen semi-transparent countdown overlay (3 → 2 → 1) over
/// the current route.
///
/// Returns `true` when the countdown completes and the plan should start.
/// Returns `false` or `null` if the user cancelled (tapped Cancel or the
/// barrier).
///
/// Usage:
/// ```dart
/// final shouldStart = await showCountdownOverlay(context);
/// if (shouldStart == true) { /* start plan */ }
/// ```
Future<bool?> showCountdownOverlay(BuildContext context) {
  return showGeneralDialog<bool>(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.black.withValues(alpha: 0.65),
    transitionDuration: const Duration(milliseconds: 200),
    transitionBuilder: (ctx, animation, _, child) {
      return FadeTransition(
        opacity: animation,
        child: child,
      );
    },
    pageBuilder: (ctx, _, __) => const _CountdownOverlayContent(),
  );
}

// ────────────────────────────────────────────────────────────────────────────
// Internal overlay widget
// ────────────────────────────────────────────────────────────────────────────

class _CountdownOverlayContent extends StatefulWidget {
  const _CountdownOverlayContent();

  @override
  State<_CountdownOverlayContent> createState() =>
      _CountdownOverlayContentState();
}

class _CountdownOverlayContentState extends State<_CountdownOverlayContent>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnim;
  late final Animation<double> _opacityAnim;

  int _count = 3;
  bool _cancelled = false;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    // Scale: pops in from small, settles, then shrinks slightly as it fades.
    _scaleAnim = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.4, end: 1.0)
            .chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 35,
      ),
      TweenSequenceItem(
        tween: ConstantTween<double>(1.0),
        weight: 40,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 0.85),
        weight: 25,
      ),
    ]).animate(_controller);

    // Opacity: fade in quickly, hold, then fade out.
    _opacityAnim = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: 1.0)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 20,
      ),
      TweenSequenceItem(
        tween: ConstantTween<double>(1.0),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 0.0)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 30,
      ),
    ]).animate(_controller);

    _runCountdown();
  }

  Future<void> _runCountdown() async {
    for (var i = 3; i >= 1; i--) {
      if (_cancelled || !mounted) return;
      setState(() => _count = i);
      _controller.reset();
      await _controller.forward();
      if (_cancelled || !mounted) return;
    }
    if (mounted && !_cancelled) {
      Navigator.of(context).pop(true);
    }
  }

  void _cancel() {
    _cancelled = true;
    _controller.stop();
    if (mounted) Navigator.of(context).pop(false);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _cancel,
        child: SizedBox.expand(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Countdown number with animation
              AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  return Opacity(
                    opacity: _opacityAnim.value.clamp(0.0, 1.0),
                    child: Transform.scale(
                      scale: _scaleAnim.value,
                      child: child,
                    ),
                  );
                },
                child: Text(
                  '$_count',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 120,
                    fontWeight: FontWeight.w900,
                    height: 1,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Starting…',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.white.withValues(alpha: 0.8),
                      letterSpacing: 1.2,
                    ),
              ),
              const SizedBox(height: 56),
              // Cancel button
              Semantics(
                button: true,
                label: 'Cancel and return to library',
                child: TextButton(
                  onPressed: _cancel,
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white70,
                    textStyle: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  child: const Text('Cancel'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
