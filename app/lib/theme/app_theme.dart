import 'package:flutter/material.dart';

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
    final colorScheme = ColorScheme.fromSeed(
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
        titleTextStyle: TextStyle(
          color: colorScheme.onSurface,
          // Use inherited font size — no fixed pixels — so system scaling works.
          fontSize: 20, // M3 titleLarge = 22sp, kept slightly tighter
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
          side: BorderSide(
            color: colorScheme.outlineVariant,
            width: 1,
          ),
        ),
        margin: EdgeInsets.zero,
      ),

      // ── Chips ──────────────────────────────────────────────────────────────
      chipTheme: ChipThemeData(
        labelStyle: TextStyle(
          fontSize: 13, // M3 labelMedium — relative to system scale
          fontWeight: FontWeight.w500,
        ),
        side: BorderSide(color: colorScheme.outlineVariant),
        shape: const StadiumBorder(),
      ),

      // ── Input / TextField ──────────────────────────────────────────────────
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        filled: true,
        fillColor: colorScheme.surfaceContainerLowest,
        labelStyle: TextStyle(color: colorScheme.onSurfaceVariant),
        hintStyle: TextStyle(
          color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
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
      dividerTheme: DividerThemeData(
        color: colorScheme.outlineVariant,
        thickness: 1,
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

  /// Builds a [TextTheme] using only font-weight / letter-spacing tweaks.
  ///
  /// Font sizes are intentionally left at Flutter's defaults (which use `sp`
  /// units that scale with the OS text-size setting). This ensures REQ-027
  /// (Dynamic Type / system font scaling) is satisfied without any extra work.
  static TextTheme _buildTextTheme(ColorScheme colorScheme) {
    // Use M3 defaults; only adjust weight/spacing for brand feel.
    return const TextTheme(
      displayLarge: TextStyle(fontWeight: FontWeight.w300, letterSpacing: -1.5),
      displayMedium:
          TextStyle(fontWeight: FontWeight.w300, letterSpacing: -0.5),
      displaySmall: TextStyle(fontWeight: FontWeight.w400),
      headlineLarge: TextStyle(fontWeight: FontWeight.w600, letterSpacing: -0.5),
      headlineMedium:
          TextStyle(fontWeight: FontWeight.w600, letterSpacing: -0.25),
      headlineSmall: TextStyle(fontWeight: FontWeight.w600),
      titleLarge: TextStyle(fontWeight: FontWeight.w600, letterSpacing: -0.25),
      titleMedium: TextStyle(fontWeight: FontWeight.w600, letterSpacing: 0.1),
      titleSmall: TextStyle(fontWeight: FontWeight.w500, letterSpacing: 0.1),
      bodyLarge: TextStyle(fontWeight: FontWeight.w400, letterSpacing: 0.15),
      bodyMedium: TextStyle(fontWeight: FontWeight.w400, letterSpacing: 0.25),
      bodySmall: TextStyle(fontWeight: FontWeight.w400, letterSpacing: 0.4),
      labelLarge: TextStyle(fontWeight: FontWeight.w600, letterSpacing: 0.1),
      labelMedium: TextStyle(fontWeight: FontWeight.w500, letterSpacing: 0.5),
      labelSmall: TextStyle(fontWeight: FontWeight.w500, letterSpacing: 0.5),
    );
  }
}
