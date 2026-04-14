import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Shared branding widgets for the "Curated Stillness" design system.
///
/// The Stitch design uses a gradient "Instructor" brand mark across all
/// AppBars: `bg-gradient-to-br from-primary to-primary-container` applied
/// as a text gradient via ShaderMask.
abstract final class AppBranding {
  /// Gradient "Instructor" brand text for AppBars.
  ///
  /// Renders the app name with a primary → primaryContainer gradient fill,
  /// Manrope extrabold at [fontSize] (default 24px per Stitch `text-2xl`).
  static Widget gradientTitle({double fontSize = 24}) {
    return Builder(
      builder: (context) {
        var colorScheme = Theme.of(context).colorScheme;
        return ShaderMask(
          shaderCallback: (bounds) => LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [colorScheme.primary, colorScheme.primaryContainer],
          ).createShader(bounds),
          child: Text(
            'Instructor',
            style: GoogleFonts.manrope(
              fontWeight: FontWeight.w800,
              fontSize: fontSize,
              color: Colors.white, // masked by shader
            ),
          ),
        );
      },
    );
  }

  /// Builds the standard branded AppBar used on most screens.
  ///
  /// Matches the Stitch design: gradient "Instructor" title on the left,
  /// optional [actions] on the right, optional [bottom] widget (e.g. a
  /// [TabBar]).
  static AppBar brandedAppBar({
    List<Widget>? actions,
    Widget? leading,
    bool centerTitle = false,
    PreferredSizeWidget? bottom,
  }) {
    return AppBar(
      title: gradientTitle(),
      centerTitle: centerTitle,
      leading: leading,
      actions: actions,
      bottom: bottom,
    );
  }
}
