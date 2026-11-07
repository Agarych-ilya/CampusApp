import 'package:flutter/material.dart';

/// A restrained, service-only palette. The rest of CampusApp keeps its theme.
class ServicePalette {
  ServicePalette._();

  // Graphite, mist blue and muted mint. No neon pink or saturated purple.
  static const Color accent = Color(0xFFAFCBFA);
  static const Color accentOnDark = Color(0xFF192A41);
  static const Color accentLightTheme = Color(0xFF365E92);
  static const Color slate = Color(0xFF91ABC9);
  static const Color mint = Color(0xFF77C5B5);
  static const Color amber = Color(0xFFE6BA7F);
  static const Color headerStart = Color(0xFF26354A);
  static const Color headerEnd = Color(0xFF172330);
  static const Color headerSubtitle = Color(0xFFCBD8EA);

  static const Color heat1 = Color(0xFF30435B);
  static const Color heat2 = Color(0xFF44678D);
  static const Color heat3 = Color(0xFF668EC0);
  static const Color heat4 = Color(0xFFAFCBFA);

  static ThemeData theme(ThemeData base) {
    final light = base.brightness == Brightness.light;
    final primary = light ? accentLightTheme : accent;
    final onPrimary = light ? Colors.white : accentOnDark;
    final scheme = base.colorScheme.copyWith(
      primary: primary,
      onPrimary: onPrimary,
      primaryContainer:
          light ? const Color(0xFFDDEAFF) : const Color(0xFF27364B),
      onPrimaryContainer:
          light ? const Color(0xFF233F62) : const Color(0xFFDCE9FF),
      secondary: light ? const Color(0xFF357D70) : mint,
      onSecondary: light ? Colors.white : const Color(0xFF132C27),
      surface: light ? const Color(0xFFFFFFFF) : const Color(0xFF111418),
      surfaceContainerLow:
          light ? const Color(0xFFF7F9FC) : const Color(0xFF171C23),
      surfaceContainer:
          light ? const Color(0xFFF1F5FA) : const Color(0xFF1D232C),
      surfaceContainerHigh:
          light ? const Color(0xFFEAF0F7) : const Color(0xFF242B35),
      surfaceContainerHighest:
          light ? const Color(0xFFDFE8F2) : const Color(0xFF303946),
      outlineVariant:
          light ? const Color(0xFFD2DAE6) : const Color(0xFF3C4653),
      onSurface:
          light ? const Color(0xFF1F2C3A) : const Color(0xFFF0F3F9),
      onSurfaceVariant:
          light ? const Color(0xFF566779) : const Color(0xFFB5C0CE),
      surfaceTint: primary,
    );
    return base.copyWith(
      colorScheme: scheme,
      scaffoldBackgroundColor:
          light ? const Color(0xFFFAFCFF) : const Color(0xFF111418),
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
