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
    final dark = Theme.of(context).brightness == Brightness.dark;
    const lavender = Color(0xFFB4A0FA);
    final idle = dark ? const Color(0xFFACABB7)
        : const Color(0xFF77717F);
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(18, 7, 18, 13),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(42),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            key: const ValueKey('campus-glass-dock'),
            height: 77,
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
            decoration: BoxDecoration(
              color: dark ? const Color(0xF1151418)
                  : const Color(0xF5F5F2FA),
              borderRadius: BorderRadius.circular(42),
              border: Border.all(
                color: dark ? const Color(0xFF26242B)
                    : const Color(0xFFDAD6E6),
              ),
            ),
            child: Row(
              children: [
                for (var index = 0; index < destinations.length; index++)
                  Expanded(
                    child: Tooltip(
                      message: destinations[index].label,
                      child: Semantics(
                        label: destinations[index].label,
                        button: true,
                        selected: currentIndex == index,
                        child: InkWell(
                          key: ValueKey('campus-glass-tab-$index'),
                          borderRadius: BorderRadius.circular(36),
                          onTap: () {
                            HapticFeedback.selectionClick();
                            onSelected(index);
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            curve: Curves.easeOutCubic,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: currentIndex == index
                                  ? (dark ? const Color(0xFF30283F)
                                      : const Color(0xFFE5DEFA))
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(36),
                            ),
                            child: Icon(
                              currentIndex == index
                                  ? destinations[index].selected
                                  : destinations[index].icon,
                              size: 26,
                              color: currentIndex == index ? lavender : idle,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
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
