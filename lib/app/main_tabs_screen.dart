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
    body: Stack(
      fit: StackFit.expand,
      children: [
        // Render the active screen behind the dock. A bottomNavigationBar
        // reserves a dark Scaffold region even when its child is translucent.
        IndexedStack(index: _currentIndex, children: _screens),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: CampusGlassDock(
            currentIndex: _currentIndex,
            onSelected: (index) => setState(() => _currentIndex = index),
          ),
        ),
      ],
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
    // The map is bright even when the app uses a dark theme.
    // Use darker glass and high-contrast icons on this tab only.
    final onMap = currentIndex == 1;
    const lavender = Color(0xFFB4A0FA);
    final idle = onMap
        ? const Color(0xFFE9E6F0)
        : dark ? const Color(0xFFACABB7)
            : const Color(0xFF77717F);
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(20, 4, 20, 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            key: const ValueKey('campus-glass-dock'),
            height: 60,
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
            decoration: BoxDecoration(
              // Dark translucent glass only over the bright map.
              // Other tabs keep the previous semi-transparent surface.
              color: onMap
                  ? const Color(0xCF17151E)
                  : dark ? const Color(0x451B1922)
                      : const Color(0x83F9F7FF),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(
                color: onMap
                    ? const Color(0x66FFFFFF)
                    : dark ? const Color(0x33FFFFFF)
                        : const Color(0x66FFFFFF),
                width: 0.8,
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
                          borderRadius: BorderRadius.circular(28),
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
                                  ? (onMap ? const Color(0xB34A3B6B)
                                      : dark ? const Color(0x87473860)
                                          : const Color(0x9AE5DEFA))
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(28),
                            ),
                            child: Icon(
                              currentIndex == index
                                  ? destinations[index].selected
                                  : destinations[index].icon,
                              size: 23,
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
