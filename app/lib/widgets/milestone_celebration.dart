/// MilestoneCelebration — full-screen overlay shown when the user's streak
/// reaches a milestone (7, 30, 100, or 365 days).
///
/// ## Features
/// - Custom confetti particle animation painted with [CustomPainter]
/// - Animated card entrance (scale + fade via [elasticOut] curve)
/// - Congratulatory headline + subtitle tailored to the milestone
/// - Gradient streak-count badge with a flame icon
/// - "Continue" button to dismiss and proceed to the library
/// - Screen-reader live-region announcement via [SemanticsService]
///
/// ## Usage
///
/// ```dart
/// if (isMilestoneStreak(newStreak)) {
///   await showMilestoneCelebration(context, newStreak);
/// }
/// ```
library milestone_celebration;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:google_fonts/google_fonts.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Public constants and helpers
// ─────────────────────────────────────────────────────────────────────────────

/// Streak counts that trigger the milestone celebration overlay.
const List<int> milestoneThresholds = [7, 30, 100, 365];

/// Returns `true` when [streak] equals one of the [milestoneThresholds].
bool isMilestoneStreak(int streak) => milestoneThresholds.contains(streak);

// ─────────────────────────────────────────────────────────────────────────────
// Public entry point
// ─────────────────────────────────────────────────────────────────────────────

/// Shows a [MilestoneCelebration] dialog for the given [streak].
///
/// Awaiting this future blocks until the user dismisses the overlay.
///
/// Example:
/// ```dart
/// await showMilestoneCelebration(context, 30);
/// ```
Future<void> showMilestoneCelebration(BuildContext context, int streak) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black87,
    builder: (ctx) => MilestoneCelebration(streak: streak),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// MilestoneCelebration widget
// ─────────────────────────────────────────────────────────────────────────────

/// Full-screen celebration overlay for streak milestones.
///
/// Rendered as a [Dialog] child so that [barrierColor] dims the background
/// while the confetti canvas paints over the entire screen.
class MilestoneCelebration extends StatefulWidget {
  const MilestoneCelebration({super.key, required this.streak});

  final int streak;

  @override
  State<MilestoneCelebration> createState() => _MilestoneCelebrationState();
}

class _MilestoneCelebrationState extends State<MilestoneCelebration>
    with TickerProviderStateMixin {
  // ── Animation controllers ──────────────────────────────────────────────────

  /// Drives the confetti particles: repeating, 3-second cycle.
  late final AnimationController _confettiController;

  /// Drives the card entrance (scale + fade).
  late final AnimationController _cardController;

  late final Animation<double> _cardScale;
  late final Animation<double> _cardOpacity;

  // ── Confetti particles ─────────────────────────────────────────────────────

  static const _particleCount = 36;
  late final List<_Particle> _particles;

  // ── Confetti colour palette ────────────────────────────────────────────────

  static const _palette = [
    Color(0xFFFFC107), // amber
    Color(0xFF4CAF50), // green
    Color(0xFF2196F3), // blue
    Color(0xFFE91E63), // pink
    Color(0xFF9C27B0), // purple
    Color(0xFF00BCD4), // cyan
    Color(0xFFFF5722), // deep orange
    Color(0xFFFFEB3B), // yellow
  ];

  @override
  void initState() {
    super.initState();

    // ── Seed particles ─────────────────────────────────────────────────────
    final rng = math.Random(widget.streak); // deterministic for the milestone
    _particles = List.generate(_particleCount, (i) {
      return _Particle(
        xFraction: rng.nextDouble(),
        delayFraction: rng.nextDouble() * 0.5,
        speedFactor: 0.45 + rng.nextDouble() * 0.55,
        size: 5 + rng.nextDouble() * 7,
        color: _palette[i % _palette.length],
        twirl: (rng.nextDouble() - 0.5) * 6,
        driftFraction: (rng.nextDouble() - 0.5) * 0.25,
        isRect: i.isEven,
      );
    });

    // ── Confetti controller ────────────────────────────────────────────────
    _confettiController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    )..repeat();

    // ── Card entrance controller ───────────────────────────────────────────
    _cardController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    );

    _cardScale = CurvedAnimation(
      parent: _cardController,
      curve: Curves.elasticOut,
    );

    _cardOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _cardController, curve: Curves.easeIn),
    );

    // ── Start entrance + announce ──────────────────────────────────────────
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _cardController.forward();
      SemanticsService.announce(
        '${_headline(widget.streak)} '
        'You have reached a ${widget.streak}-day streak!',
        TextDirection.ltr,
      ).ignore();
    });
  }

  @override
  void dispose() {
    _confettiController.dispose();
    _cardController.dispose();
    super.dispose();
  }

  // ── Content helpers ────────────────────────────────────────────────────────

  String _headline(int streak) => switch (streak) {
        7 => '🔥 One Week Streak!',
        30 => '🌟 30-Day Streak!',
        100 => '💎 100-Day Streak!',
        365 => '🏆 Year-Long Streak!',
        _ => '🎉 ${streak}-Day Streak!',
      };

  String _subtitle(int streak) => switch (streak) {
        7 => 'A week of consistent practice!',
        30 => 'A full month of dedication!',
        100 => 'Triple digits — truly incredible!',
        365 => 'A complete year of daily growth!',
        _ => 'Amazing consistency — keep it up!',
      };

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final screenSize = MediaQuery.of(context).size;

    return Semantics(
      // Mark as a live region so TalkBack / VoiceOver re-reads when shown.
      liveRegion: true,
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.zero,
        child: SizedBox.expand(
          child: Stack(
            children: [
              // ── Confetti canvas — fills the whole screen ───────────────────
              AnimatedBuilder(
                animation: _confettiController,
                builder: (ctx, _) => CustomPaint(
                  size: screenSize,
                  painter: _ConfettiPainter(
                    particles: _particles,
                    progress: _confettiController.value,
                  ),
                ),
              ),

              // ── Celebration card ───────────────────────────────────────────
              Center(
                child: FadeTransition(
                  opacity: _cardOpacity,
                  child: ScaleTransition(
                    scale: _cardScale,
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 28),
                      padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
                      decoration: BoxDecoration(
                        color: colorScheme.surface,
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: [
                          BoxShadow(
                            color:
                                colorScheme.primary.withValues(alpha: 0.22),
                            blurRadius: 48,
                            spreadRadius: 4,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // ── Headline ─────────────────────────────────────
                          Text(
                            _headline(widget.streak),
                            textAlign: TextAlign.center,
                            style: GoogleFonts.manrope(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5,
                              color: colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 8),

                          // ── Subtitle ──────────────────────────────────────
                          Text(
                            _subtitle(widget.streak),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 15,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 24),

                          // ── Streak badge ─────────────────────────────────
                          Semantics(
                            label:
                                '${widget.streak} day streak',
                            excludeSemantics: true,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    colorScheme.primary,
                                    colorScheme.primaryContainer,
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(40),
                                boxShadow: [
                                  BoxShadow(
                                    color: colorScheme.primary
                                        .withValues(alpha: 0.3),
                                    blurRadius: 20,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.local_fire_department,
                                    color: colorScheme.onPrimary,
                                    size: 28,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '${widget.streak} days',
                                    style: GoogleFonts.manrope(
                                      fontSize: 26,
                                      fontWeight: FontWeight.w800,
                                      color: colorScheme.onPrimary,
                                      letterSpacing: -0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 28),

                          // ── Continue button ───────────────────────────────
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton(
                              onPressed: () => Navigator.of(context).pop(),
                              style: FilledButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text(
                                'Continue',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Confetti data model
// ─────────────────────────────────────────────────────────────────────────────

/// Immutable description of a single confetti particle.
@immutable
class _Particle {
  const _Particle({
    required this.xFraction,
    required this.delayFraction,
    required this.speedFactor,
    required this.size,
    required this.color,
    required this.twirl,
    required this.driftFraction,
    required this.isRect,
  });

  /// Normalised horizontal starting position (0..1).
  final double xFraction;

  /// Normalised delay before the particle begins to fall (0..1).
  final double delayFraction;

  /// Relative speed multiplier (0.45..1.0).
  final double speedFactor;

  /// Particle diameter / side length in logical pixels.
  final double size;

  final Color color;

  /// Rotation speed in full turns per animation cycle.
  final double twirl;

  /// Horizontal drift as a fraction of screen width per cycle.
  final double driftFraction;

  /// `true` → rounded rectangle; `false` → circle.
  final bool isRect;
}

// ─────────────────────────────────────────────────────────────────────────────
// Confetti painter
// ─────────────────────────────────────────────────────────────────────────────

/// Paints all [_Particle]s onto the canvas according to the current [progress]
/// value from the animation controller (0.0 → 1.0, repeating).
class _ConfettiPainter extends CustomPainter {
  const _ConfettiPainter({
    required this.particles,
    required this.progress,
  });

  final List<_Particle> particles;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    for (int i = 0; i < particles.length; i++) {
      final p = particles[i];

      // Adjust progress by the particle's delay so they start at different
      // times during the animation cycle.
      final adjusted =
          ((progress - p.delayFraction) / (1.0 - p.delayFraction))
              .clamp(0.0, 1.0);

      if (adjusted <= 0) continue;

      // Vertical position: top-edge → bottom-edge, scaled by speed
      final y =
          -p.size + (size.height + p.size * 2) * adjusted * p.speedFactor;
      if (y > size.height + p.size) continue;

      // Horizontal position with sinusoidal drift
      final x = size.width * p.xFraction +
          size.width * p.driftFraction * math.sin(adjusted * math.pi * 2);

      final rotation = adjusted * p.twirl * math.pi * 2;

      paint.color = p.color.withValues(alpha: 0.88);

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(rotation);

      if (p.isRect) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: Offset.zero,
              width: p.size,
              height: p.size * 0.55,
            ),
            const Radius.circular(2),
          ),
          paint,
        );
      } else {
        canvas.drawCircle(Offset.zero, p.size * 0.42, paint);
      }

      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.progress != progress;
}
