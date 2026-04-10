import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Gradient CTA button matching the Stitch "Curated Stillness" design system.
///
/// Uses a 135° linear gradient from `primary` to `primaryContainer` with an
/// ambient shadow. Text is Manrope bold, uppercase with wide tracking.
class GradientButton extends StatelessWidget {
  const GradientButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.height = 56,
    this.borderRadius = 12,
    this.width,
  });

  final VoidCallback? onPressed;
  final Widget child;
  final double height;
  final double borderRadius;
  final double? width;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isEnabled = onPressed != null;

    return SizedBox(
      width: width,
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: isEnabled
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    colorScheme.primary,
                    colorScheme.primaryContainer,
                  ],
                )
              : null,
          color: isEnabled ? null : colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(borderRadius),
          boxShadow: isEnabled
              ? [
                  BoxShadow(
                    color: colorScheme.primary.withValues(alpha: 0.25),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ]
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(borderRadius),
            child: Center(child: child),
          ),
        ),
      ),
    );
  }

  /// Convenience factory for a standard text-label gradient button.
  static Widget label({
    Key? key,
    required String text,
    required VoidCallback? onPressed,
    IconData? icon,
    double height = 56,
    double borderRadius = 12,
    double? width,
  }) {
    return Builder(
      builder: (context) {
        final colorScheme = Theme.of(context).colorScheme;
        return GradientButton(
          key: key,
          onPressed: onPressed,
          height: height,
          borderRadius: borderRadius,
          width: width,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                text,
                style: GoogleFonts.manrope(
                  color: colorScheme.onPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  letterSpacing: 1.5,
                ),
              ),
              if (icon != null) ...[
                const SizedBox(width: 8),
                Icon(icon, color: colorScheme.onPrimary, size: 20),
              ],
            ],
          ),
        );
      },
    );
  }
}
