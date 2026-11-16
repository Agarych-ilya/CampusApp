import 'package:flutter/material.dart';

/// A shared service palette aligned with the reference schedule's near-black
/// surfaces and muted violet accents.
class ServicePalette {
  ServicePalette._();

  // Ninja-like: neutral graphite surfaces and reference violet accents.
  // Green is reserved for the study activity heatmap.
  static const Color accent = Color(0xFFA58CFA);
  static const Color accentOnDark = Color(0xFF22172F);
  static const Color accentLightTheme = Color(0xFF7057B9);
  static const Color slate = Color(0xFFAA94E6);
  static const Color mint = Color(0xFF87B8AD);
  static const Color amber = Color(0xFFD1B68E);
  static const Color headerStart = Color(0xFF201E26);
  static const Color headerEnd = Color(0xFF111014);
  static const Color headerSubtitle = Color(0xFFC1C1CB);

  static const Color heat1 = Color(0xFF0E4429);
  static const Color heat2 = Color(0xFF006D32);
  static const Color heat3 = Color(0xFF26A641);
  static const Color heat4 = Color(0xFF39D353);

  static ThemeData theme(ThemeData base) {
    final light = base.brightness == Brightness.light;
    final primary = light ? accentLightTheme : accent;
    final onPrimary = light ? Colors.white : accentOnDark;
    final scheme = base.colorScheme.copyWith(
      primary: primary,
      onPrimary: onPrimary,
      primaryContainer:
          light ? const Color(0xFFE3EDFF) : const Color(0xFF302838),
      onPrimaryContainer:
          light ? const Color(0xFF443567) : const Color(0xFFE4EEFF),
      secondary: light ? const Color(0xFF457C92) : mint,
      onSecondary: light ? Colors.white : const Color(0xFF142D38),
      surface: light ? const Color(0xFFFFFFFF) : const Color(0xFF0F0F10),
      surfaceContainerLow:
          light ? const Color(0xFFF8F8F9) : const Color(0xFF151418),
      surfaceContainer:
          light ? const Color(0xFFF2F2F4) : const Color(0xFF1D1B22),
      surfaceContainerHigh:
          light ? const Color(0xFFEAEAED) : const Color(0xFF26232D),
      surfaceContainerHighest:
          light ? const Color(0xFFE0E0E5) : const Color(0xFF302C37),
      outlineVariant:
          light ? const Color(0xFFD5D5DD) : const Color(0xFF37373E),
      onSurface:
          light ? const Color(0xFF1C1C20) : const Color(0xFFF5F5F7),
      onSurfaceVariant:
          light ? const Color(0xFF62626D) : const Color(0xFFA5A5AF),
      // Keep background panels neutral, without a blue Material tint.
      surfaceTint: Colors.transparent,
      tertiary: light ? const Color(0xFF607BA5) : slate,
      onTertiary: light ? Colors.white : accentOnDark,
      secondaryContainer:
          light ? const Color(0xFFE6E9EF) : const Color(0xFF28282D),
      onSecondaryContainer:
          light ? const Color(0xFF333E52) : const Color(0xFFDDE2EC),
    );
    return base.copyWith(
      colorScheme: scheme,
      appBarTheme: base.appBarTheme.copyWith(
        backgroundColor: light ? const Color(0xFFFAFAFB) : const Color(0xFF0F0F10),
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      scaffoldBackgroundColor:
          light ? const Color(0xFFFAFAFB) : const Color(0xFF0F0F10),
      chipTheme: base.chipTheme.copyWith(
        selectedColor: primary.withOpacity(0.19),
        backgroundColor: scheme.surfaceContainer,
        side: BorderSide(color: scheme.outlineVariant),
        labelStyle: TextStyle(color: scheme.onSurface),
      ),
      inputDecorationTheme: base.inputDecorationTheme.copyWith(
        fillColor: scheme.surfaceContainer,
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: primary, width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
      ),
    );
  }

  static Widget wrap(BuildContext context, Widget child) =>
      Theme(data: theme(Theme.of(context)), child: child);
}
