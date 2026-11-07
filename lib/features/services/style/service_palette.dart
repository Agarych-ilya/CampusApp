import 'package:flutter/material.dart';

/// A restrained, service-only palette. The rest of CampusApp keeps its theme.
class ServicePalette {
  ServicePalette._();

  // Graphite, mist blue and muted mint. Neutral surfaces, soft sage controls, GitHub-green activity intensity.
  static const Color accent = Color(0xFFE0E7DE);
  static const Color accentOnDark = Color(0xFF1F2A22);
  static const Color accentLightTheme = Color(0xFF3E654D);
  static const Color slate = Color(0xFFABB8A8);
  static const Color mint = Color(0xFF82CBA3);
  static const Color amber = Color(0xFFE7BD70);
  static const Color headerStart = Color(0xFF2C312C);
  static const Color headerEnd = Color(0xFF1B201C);
  static const Color headerSubtitle = Color(0xFFC7D0C6);

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
          light ? const Color(0xFFE2EFE1) : const Color(0xFF293A2D),
      onPrimaryContainer:
          light ? const Color(0xFF2C5334) : const Color(0xFFE2F0E2),
      secondary: light ? const Color(0xFF397B55) : mint,
      onSecondary: light ? Colors.white : const Color(0xFF183322),
      surface: light ? const Color(0xFFFFFFFF) : const Color(0xFF121512),
      surfaceContainerLow:
          light ? const Color(0xFFF5F8F4) : const Color(0xFF191D19),
      surfaceContainer:
          light ? const Color(0xFFF0F5EE) : const Color(0xFF202520),
      surfaceContainerHigh:
          light ? const Color(0xFFEAF1E8) : const Color(0xFF282E29),
      surfaceContainerHighest:
          light ? const Color(0xFFDFE9DE) : const Color(0xFF333A34),
      outlineVariant:
          light ? const Color(0xFFD4DFD2) : const Color(0xFF434A44),
      onSurface:
          light ? const Color(0xFF233026) : const Color(0xFFF0F4EF),
      onSurfaceVariant:
          light ? const Color(0xFF5B6B5E) : const Color(0xFFB8C2B6),
      surfaceTint: primary,
    );
    return base.copyWith(
      colorScheme: scheme,
      scaffoldBackgroundColor:
          light ? const Color(0xFFFAFCF9) : const Color(0xFF121512),
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
