import 'package:flutter/material.dart';

/// CampusApp logo uses the global accent, so legacy magenta pixels in
/// the transparent image asset never appear in the interface.
class CampusLogo extends StatelessWidget {
  const CampusLogo({super.key});

  @override
  Widget build(BuildContext context) {
    return ColorFiltered(
      colorFilter: ColorFilter.mode(
        Theme.of(context).colorScheme.primary,
        BlendMode.srcIn,
      ),
      child: Image.asset(
        'assets/images/logo/logo_main.png',
        width: 130,
        height: 105,
        fit: BoxFit.contain,
      ),
    );
  }
}
