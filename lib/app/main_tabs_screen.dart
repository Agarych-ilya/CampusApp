import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '/features/schedule/schedule.dart';
import '/features/services/services.dart';
import '/features/profile/profile.dart';
import '/features/map/view/campus_map_screen.dart';

class MainTabsScreen extends StatefulWidget {
  const MainTabsScreen({super.key});

  @override
  State<MainTabsScreen> createState() => _MainTabsScreenState();
}

class _MainTabsScreenState extends State<MainTabsScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    ScheduleScreen(),
    CampusMapScreen(),
    _EmptyTabScreen(
      title: 'Чаты',
      subtitle: 'Здесь появятся ваши сообщения',
      icon: Icons.chat_bubble_outline_rounded,
    ),
    ServicesScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) => Scaffold(
    extendBody: true,
    body: IndexedStack(index: _currentIndex, children: _screens),
    bottomNavigationBar: CampusGlassDock(
      currentIndex: _currentIndex,
      onSelected: (index) => setState(() => _currentIndex = index),
    ),
  );
}

/// A floating, accessible glass dock inspired by the supplied reference.
/// Icons are the only visible navigation labels; their names remain available
/// to accessibility services and long-press tooltips.
class CampusGlassDock extends StatelessWidget {
  const CampusGlassDock({
    required this.currentIndex,
    required this.onSelected,
    super.key,
  });

  final int currentIndex;
  final ValueChanged<int> onSelected;

  static const destinations = [
    (label: 'Расписание', icon: Icons.calendar_today_outlined,
      selected: Icons.calendar_month_rounded),
    (label: 'Кампус', icon: Icons.map_outlined,
      selected: Icons.map_rounded),
    (label: 'Чаты', icon: Icons.chat_bubble_outline_rounded,
      selected: Icons.chat_bubble_rounded),
    (label: 'Сервисы', icon: Icons.grid_view_outlined,
      selected: Icons.grid_view_rounded),
    (label: 'Профиль', icon: Icons.person_outline_rounded,
      selected: Icons.person_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(18, 8, 18, 14),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
          child: Container(
            key: const ValueKey('campus-glass-dock'),
            height: 68,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(32),
              color: dark
                  ? const Color(0xDA1B2636)
                  : const Color(0xEAF6FAFF),
              border: Border.all(
                color: Colors.white.withOpacity(dark ? 0.18 : 0.65),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(dark ? 0.24 : 0.08),
                  blurRadius: 28, offset: const Offset(0, 12),
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 6),
            child: Row(
              children: List.generate(destinations.length, (index) {
                final item = destinations[index];
                final selected = index == currentIndex;
                return Expanded(
                  child: Tooltip(
                    message: item.label,
                    child: Semantics(
                      label: item.label,
                      selected: selected,
                      button: true,
                      child: InkWell(
                        key: ValueKey('campus-glass-tab-$index'),
                        onTap: () {
                          HapticFeedback.selectionClick();
                          onSelected(index);
                        },
                        borderRadius: BorderRadius.circular(25),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 230),
                          curve: Curves.easeOutCubic,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: selected
                                ? scheme.primary.withOpacity(dark ? 0.22 : 0.15)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: selected
                                  ? scheme.primary.withOpacity(0.32)
                                  : Colors.transparent,
                            ),
                          ),
                          child: Icon(
                            selected ? item.selected : item.icon,
                            size: selected ? 25 : 23,
                            color: selected
                                ? scheme.primary : scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyTabScreen extends StatelessWidget {
  const _EmptyTabScreen({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Icon(icon, size: 40,
                    color: theme.colorScheme.primary),
              ),
              const SizedBox(height: 22),
              Text(title, style: theme.textTheme.headlineMedium),
              const SizedBox(height: 10),
              Text(subtitle, textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  )),
            ],
          ),
        ),
      ),
    );
  }
}
