import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:campusapp/features/services/style/service_palette.dart';

void main() {
  test('dark services use neutral backgrounds with blue controls', () {
    final original = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.pink,
        brightness: Brightness.dark,
      ),
    );
    final theme = ServicePalette.theme(original);

    // Match Ninja MIREA's visual hierarchy, not its branding.
    expect(theme.scaffoldBackgroundColor, const Color(0xFF0F0F10));
    expect(theme.colorScheme.surface, const Color(0xFF0F0F10));
    expect(theme.colorScheme.surfaceContainer, const Color(0xFF1B1B1E));
    expect(theme.colorScheme.primary, const Color(0xFFAAC8FF));
    expect(theme.colorScheme.surfaceTint, Colors.transparent);
    expect(theme.appBarTheme.backgroundColor, const Color(0xFF0F0F10));
    expect(ServicePalette.headerStart, const Color(0xFF222225));
  });

  test('17-week learning intensity remains green', () {
    expect(ServicePalette.heat1, const Color(0xFF0E4429));
    expect(ServicePalette.heat2, const Color(0xFF006D32));
    expect(ServicePalette.heat3, const Color(0xFF26A641));
    expect(ServicePalette.heat4, const Color(0xFF39D353));
  });
}
