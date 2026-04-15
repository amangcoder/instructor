import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Material 3 theme configuration for the Instructor app.
///
/// ## Design decisions
/// - Uses [colorSchemeSeed] to generate a harmonious M3 colour scheme from a
///   single brand seed colour.
/// - All [TextStyle] font sizes are expressed as **relative** values via
///   [TextScaler] — no fixed-pixel overrides — so the OS Dynamic Type /
///   system font-scaling preference is always respected (REQ-027).
/// - Provides both [light] and [dark] variants. [ThemeMode.system] is used in
///   [InstructorApp] so the OS preference is honoured automatically.
abstract final class AppTheme {
  // ────────────────────────────────────────────────────────────────────────────
  // Brand seed colour
  // ────────────────────────────────────────────────────────────────────────────

  /// The single seed colour from which the entire Material 3 colour scheme is
  /// derived via tonal palette generation.
  static const Color _seedColor = Color(0xFF5B6BE8); // Indigo-violet

  // ────────────────────────────────────────────────────────────────────────────
  // Public factory methods
  // ────────────────────────────────────────────────────────────────────────────

  /// Builds the light [ThemeData] for the Instructor app.
  static ThemeData light() => _build(Brightness.light);

  /// Builds the dark [ThemeData] for the Instructor app.
  static ThemeData dark() => _build(Brightness.dark);

  // ────────────────────────────────────────────────────────────────────────────
  // Private builder
  // ────────────────────────────────────────────────────────────────────────────

  static ThemeData _build(Brightness brightness) {
    // Use explicit "Curated Stillness" color scheme from Stitch design
    final colorScheme = brightness == Brightness.light
        ? const ColorScheme(
            brightness: Brightness.light,
            primary: Color(0xFF565C8C),
            onPrimary: Color(0xFFFBF8FF),
            primaryContainer: Color(0xFFC0C6FD),
            onPrimaryContainer: Color(0xFF393E6D),
            secondary: Color(0xFF5C5E72),
            onSecondary: Color(0xFFFBF8FF),
            secondaryContainer: Color(0xFFE0E0F9),
            onSecondaryContainer: Color(0xFF4F5065),
            tertiary: Color(0xFF72557B),
            onTertiary: Color(0xFFFFF7FB),
            tertiaryContainer: Color(0xFFEDC8F5),
            onTertiaryContainer: Color(0xFF5A3F64),
            error: Color(0xFFA8364B),
            onError: Color(0xFFFFF7F7),
            errorContainer: Color(0xFFF97386),
            onErrorContainer: Color(0xFF6E0523),
            surface: Color(0xFFFBF8FE),
            onSurface: Color(0xFF31323B),
            onSurfaceVariant: Color(0xFF5E5E68),
            surfaceContainerLowest: Color(0xFFFFFFFF),
            surfaceContainerLow: Color(0xFFF5F2FB),
            surfaceContainer: Color(0xFFEFECF6),
            surfaceContainerHigh: Color(0xFFE9E7F1),
            surfaceContainerHighest: Color(0xFFE3E1ED),
            outline: Color(0xFF7A7A84),
            outlineVariant: Color(0xFFB2B1BC),
            shadow: Color(0xFF000000),
            inverseSurface: Color(0xFF0E0E12),
            onInverseSurface: Color(0xFF9E9CA2),
            inversePrimary: Color(0xFFC0C6FD),
            surfaceTint: Color(0xFF565C8C),
            scrim: Color(0xFF000000),
          )
        : ColorScheme.fromSeed(
            seedColor: _seedColor,
            brightness: brightness,
          );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,

      // ── Typography ─────────────────────────────────────────────────────────
      // Flutter's default Material 3 typography already uses sp units (scaled
      // pixels) which respect the system font-scale factor. We do NOT override
      // fontSize with fixed dp values, ensuring REQ-027 compliance.
      //
      // We only customise letterSpacing / height where needed for aesthetics.
      textTheme: _buildTextTheme(colorScheme),

      // ── AppBar ─────────────────────────────────────────────────────────────
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 2,
        centerTitle: false,
        titleTextStyle: GoogleFonts.manrope(
          color: colorScheme.onSurface,
          fontSize: 20,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.25,
        ),
      ),

      // ── Cards ──────────────────────────────────────────────────────────────
      cardTheme: CardThemeData(
        elevation: 0,
        color: colorScheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          // No border line (Curated Stillness: no-border design rule)
        ),
        margin: EdgeInsets.zero,
      ),

      // ── Chips ──────────────────────────────────────────────────────────────
      // Stitch: px-6 py-2.5 rounded-full, selected bg-primary text-on-primary
      chipTheme: ChipThemeData(
        labelStyle: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: colorScheme.onSurface,
        ),
        secondaryLabelStyle: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: colorScheme.onPrimary,
        ),
        side: BorderSide.none,
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        backgroundColor: colorScheme.surfaceContainerHighest,
        selectedColor: colorScheme.primary,
        checkmarkColor: colorScheme.onPrimary,
        labelPadding: const EdgeInsets.symmetric(horizontal: 4),
        showCheckmark: false,
      ),

      // ── Input / TextField ──────────────────────────────────────────────────
      // Stitch: filled surface-container-highest, rounded-xl, no visible border
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: colorScheme.primary.withValues(alpha: 0.4),
            width: 1,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 16,
        ),
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest,
        labelStyle: TextStyle(color: colorScheme.onSurfaceVariant),
        hintStyle: TextStyle(
          color: colorScheme.outlineVariant,
        ),
      ),

      // ── Floating Action Button ─────────────────────────────────────────────
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colorScheme.primaryContainer,
        foregroundColor: colorScheme.onPrimaryContainer,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),

      // ── Elevated Button ────────────────────────────────────────────────────
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          minimumSize: const Size(64, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 15, // relative — scaled by system
            fontWeight: FontWeight.w600,
            letterSpacing: 0.1,
          ),
        ),
      ),

      // ── Filled Button ──────────────────────────────────────────────────────
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.1,
          ),
        ),
      ),

      // ── Text Button ────────────────────────────────────────────────────────
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(64, 40),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.1,
          ),
        ),
      ),

      // ── Bottom Navigation Bar ──────────────────────────────────────────────
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: colorScheme.surfaceContainer,
        indicatorColor: colorScheme.primaryContainer,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 12, // relative
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected
                ? colorScheme.onSurface
                : colorScheme.onSurfaceVariant,
          );
        }),
      ),

      // ── Divider ────────────────────────────────────────────────────────────
      // No-line rule: dividers are invisible by default (tonal layering instead)
      dividerTheme: const DividerThemeData(
        color: Colors.transparent,
        thickness: 0,
        space: 1,
      ),

      // ── List Tile ──────────────────────────────────────────────────────────
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),

      // ── Dialog ─────────────────────────────────────────────────────────────
      dialogTheme: DialogThemeData(
        backgroundColor: colorScheme.surfaceContainerHigh,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
        ),
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: colorScheme.onSurface,
        ),
        contentTextStyle: TextStyle(
          fontSize: 15,
          color: colorScheme.onSurfaceVariant,
          height: 1.5,
        ),
      ),

      // ── Snack Bar ──────────────────────────────────────────────────────────
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        backgroundColor: colorScheme.inverseSurface,
        contentTextStyle: TextStyle(
          color: colorScheme.onInverseSurface,
          fontSize: 14,
        ),
      ),
    );
  }

  // ────────────────────────────────────────────────────────────────────────────
  // Typography helper
  // ────────────────────────────────────────────────────────────────────────────

  /// Builds a [TextTheme] using Manrope (headlines/display) + Inter (body/labels).
  ///
  /// Manrope provides the "Editorial Authority" for headlines, while Inter offers
  /// high-utility legibility for instructional body text. Font sizes follow Flutter's
  /// M3 defaults (using `sp` units) to respect system font scaling (REQ-027).
  static TextTheme _buildTextTheme(ColorScheme colorScheme) {
    // Pass a colour-aware base text theme so Google Fonts inherits the correct
    // foreground colour (onSurface) for the current brightness instead of
    // defaulting to black, which is invisible in dark mode.
    final base = ThemeData(colorScheme: colorScheme, useMaterial3: true).textTheme;
    final manrope = GoogleFonts.manropeTextTheme(base);
    final inter = GoogleFonts.interTextTheme(base);
    return TextTheme(
      // Display & Headlines → Manrope (editorial voice)
      displayLarge: manrope.displayLarge?.copyWith(
        fontWeight: FontWeight.w300,
        letterSpacing: -1.5,
      ),
      displayMedium: manrope.displayMedium?.copyWith(
        fontWeight: FontWeight.w300,
        letterSpacing: -0.5,
      ),
      displaySmall: manrope.displaySmall?.copyWith(
        fontWeight: FontWeight.w400,
      ),
      headlineLarge: manrope.headlineLarge?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: -0.5,
      ),
      headlineMedium: manrope.headlineMedium?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: -0.25,
      ),
      headlineSmall: manrope.headlineSmall?.copyWith(
        fontWeight: FontWeight.w600,
      ),
      titleLarge: manrope.titleLarge?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: -0.25,
      ),
      // Body & Labels → Inter (instructional voice)
      titleMedium: inter.titleMedium?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: 0.1,
      ),
      titleSmall: inter.titleSmall?.copyWith(
        fontWeight: FontWeight.w500,
        letterSpacing: 0.1,
      ),
      bodyLarge: inter.bodyLarge?.copyWith(
        fontWeight: FontWeight.w400,
        letterSpacing: 0.15,
      ),
      bodyMedium: inter.bodyMedium?.copyWith(
        fontWeight: FontWeight.w400,
        letterSpacing: 0.25,
      ),
      bodySmall: inter.bodySmall?.copyWith(
        fontWeight: FontWeight.w400,
        letterSpacing: 0.4,
      ),
      labelLarge: inter.labelLarge?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: 0.1,
      ),
      labelMedium: inter.labelMedium?.copyWith(
        fontWeight: FontWeight.w500,
        letterSpacing: 0.5,
      ),
      labelSmall: inter.labelSmall?.copyWith(
        fontWeight: FontWeight.w500,
        letterSpacing: 0.5,
      ),
    );
  }
}
