import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:instructor/screens/onboarding/widgets/template_picker_sheet.dart';
import 'package:instructor/theme/gradient_button.dart';

/// Stitch onboarding: hero image area, "Your personal life conductor" heading,
/// bento template grid, glassmorphic bottom with gradient "Get Started" button.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  Future<void> _getStarted() async {
    await showTemplatePickerSheet(context);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: Stack(
        children: [
          // ── Scrollable content ──────────────────────────────────────────
          SafeArea(
            bottom: false,
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 160),
              child: Column(
                children: [
                  // ── Hero image area ─────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(32, 48, 32, 0),
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              colorScheme.primaryContainer
                                  .withValues(alpha: 0.4),
                              colorScheme.tertiaryContainer
                                  .withValues(alpha: 0.3),
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: colorScheme.primary
                                  .withValues(alpha: 0.12),
                              blurRadius: 48,
                              offset: const Offset(0, 24),
                            ),
                          ],
                        ),
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(24),
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Colors.transparent,
                                      colorScheme.primary
                                          .withValues(alpha: 0.4),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            Center(
                              child: Icon(
                                Icons.self_improvement,
                                size: 96,
                                color: colorScheme.onPrimary
                                    .withValues(alpha: 0.7),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // ── Title ───────────────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      'Your personal life conductor.',
                      style: GoogleFonts.manrope(
                        fontSize: 36,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                        color: colorScheme.primary,
                        height: 1.1,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ── Subtitle ────────────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Text(
                      'Author timed guidance that runs in the background. Voice guides you, so you stay focused.',
                      style: TextStyle(
                        fontSize: 18,
                        color: colorScheme.onSurfaceVariant,
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),

                  const SizedBox(height: 40),

                  // ── Template picker bento grid ──────────────────────────
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 8),
                          child: Row(
                            mainAxisAlignment:
                                MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Pick a Template',
                                style: GoogleFonts.manrope(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  color: colorScheme.onSurface,
                                ),
                              ),
                              Icon(Icons.arrow_forward,
                                  color: colorScheme.primary),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Full-width card
                        _TemplateCard(
                          icon: Icons.light_mode,
                          title: 'Morning Flow',
                          subtitle: '15 min routine',
                          isFullWidth: true,
                          gradient: true,
                          onTap: _getStarted,
                        ),
                        const SizedBox(height: 16),

                        // Two square cards
                        Row(
                          children: [
                            Expanded(
                              child: _TemplateCard(
                                icon: Icons.fitness_center,
                                title: 'Quick Workout',
                                subtitle: '7 min burst',
                                onTap: _getStarted,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _TemplateCard(
                                icon: Icons.bolt,
                                title: 'Productivity Sprint',
                                subtitle: '25 min focus',
                                onTap: _getStarted,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Fixed glassmorphic bottom ───────────────────────────────────
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                child: Container(
                  color: colorScheme.surface.withValues(alpha: 0.7),
                  padding: const EdgeInsets.fromLTRB(32, 24, 32, 40),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GradientButton(
                        onPressed: _getStarted,
                        height: 56,
                        borderRadius: 12,
                        width: double.infinity,
                        child: Text(
                          'GET STARTED',
                          style: GoogleFonts.manrope(
                            color: colorScheme.onPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _Dot(active: true, color: colorScheme.primary),
                          const SizedBox(width: 4),
                          _Dot(color: colorScheme.outlineVariant),
                          const SizedBox(width: 4),
                          _Dot(color: colorScheme.outlineVariant),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Sub-widgets ──────────────────────────────────────────────────────────────

class _TemplateCard extends StatelessWidget {
  const _TemplateCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.isFullWidth = false,
    this.gradient = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool isFullWidth;
  final bool gradient;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (isFullWidth) {
      return GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: gradient
                      ? LinearGradient(colors: [
                          colorScheme.primary,
                          colorScheme.primaryContainer,
                        ])
                      : null,
                  color: gradient ? null : colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: colorScheme.onPrimary),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: GoogleFonts.manrope(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: colorScheme.primary)),
                    Text(subtitle,
                        style: TextStyle(
                            fontSize: 14,
                            color: colorScheme.onSurfaceVariant)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: colorScheme.outlineVariant),
            ],
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: onTap,
      child: AspectRatio(
        aspectRatio: 1,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon,
                    color: colorScheme.onSecondaryContainer, size: 22),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: GoogleFonts.manrope(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: colorScheme.primary,
                          height: 1.2)),
                  const SizedBox(height: 4),
                  Text(subtitle,
                      style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.onSurfaceVariant)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.color, this.active = false});

  final bool active;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: active ? color : color.withValues(alpha: 0.4),
      ),
    );
  }
}
