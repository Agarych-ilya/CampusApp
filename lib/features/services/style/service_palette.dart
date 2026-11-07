import 'package:flutter/material.dart';

/// A restrained, service-only palette. The rest of CampusApp keeps its theme.
class ServicePalette {
  ServicePalette._();

  // Ninja MIREA-like: neutral graphite surfaces, light-blue accents.
  // Green is reserved for the study activity heatmap.
  static const Color accent = Color(0xFFAAC8FF);
  static const Color accentOnDark = Color(0xFF182B4B);
  static const Color accentLightTheme = Color(0xFF3464A6);
  static const Color slate = Color(0xFF95B5E8);
  static const Color mint = Color(0xFF78C0A9);
  static const Color amber = Color(0xFFF0BF78);
  static const Color headerStart = Color(0xFF222225);
  static const Color headerEnd = Color(0xFF18181B);
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
          light ? const Color(0xFFE3EDFF) : const Color(0xFF2A3343),
      onPrimaryContainer:
          light ? const Color(0xFF24466F) : const Color(0xFFE4EEFF),
      secondary: light ? const Color(0xFF457C92) : mint,
      onSecondary: light ? Colors.white : const Color(0xFF142D38),
      surface: light ? const Color(0xFFFFFFFF) : const Color(0xFF0F0F10),
      surfaceContainerLow:
          light ? const Color(0xFFF8F8F9) : const Color(0xFF151517),
      surfaceContainer:
          light ? const Color(0xFFF2F2F4) : const Color(0xFF1B1B1E),
      surfaceContainerHigh:
          light ? const Color(0xFFEAEAED) : const Color(0xFF232327),
      surfaceContainerHighest:
          light ? const Color(0xFFE0E0E5) : const Color(0xFF2D2D32),
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
