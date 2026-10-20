import 'package:flutter/material.dart';

import '../data/bars_subject.dart';
import '../data/student_profile.dart';

/// The ranking is deliberately a placeholder until the university provides
/// authorized cohort data. Only local BARS information is used for the
/// activity counters displayed below.
class ProfileStatisticsView extends StatelessWidget {
  const ProfileStatisticsView({
    super.key,
    required this.profile,
    required this.subjects,
  });

  final StudentProfile? profile;
  final List<BarsSubject> subjects;

  int get _gradedActivities {
    final gradePattern = RegExp(r'^\s*[2-5](?=\s|$)');
    var count = 0;

    for (final subject in subjects) {
      for (final control in subject.controls) {
        if (gradePattern.hasMatch(control.grade)) count++;
      }
    }
    return count;
  }

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final group = profile?.group.trim() ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Статистика',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 6),
        Text(
          'Твои достижения и место среди студентов',
          style: TextStyle(color: muted, fontSize: 13),
        ),
        const SizedBox(height: 22),
        Text(
          'Рейтинг',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _RankingCard(
                title: 'В группе',
                subtitle: group.isEmpty ? 'Твоя группа' : group,
                icon: Icons.groups_2_outlined,
                accent: const Color(0xFF60A5FA),
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: _RankingCard(
                title: 'На потоке',
                subtitle: 'Среди студентов потока',
                icon: Icons.emoji_events_outlined,
                accent: Color(0xFF8B8CF8),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: _cardColor(context),
            borderRadius: BorderRadius.circular(17),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline, size: 20, color: muted),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Рейтинг пока недоступен. Места в группе и на потоке '
                  'появятся после подключения разрешённых данных '
                  'университета. Сейчас отображается заглушка.',
                  style: TextStyle(
                    color: muted,
                    fontSize: 12,
                    height: 1.45,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 27),
        Text(
          'Данные из БАРС',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _ActivityCard(
                icon: Icons.menu_book_outlined,
                label: 'Предметов',
                value: subjects.length.toString(),
                accent: const Color(0xFF38BDF8),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _ActivityCard(
                icon: Icons.check_circle_outline,
                label: 'Оценок за работы',
                value: _gradedActivities.toString(),
                accent: const Color(0xFF2DD4BF),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          'Счётчики основаны только на загруженных семестрах БАРС.',
          style: TextStyle(color: muted, fontSize: 11),
        ),
        const SizedBox(height: 28),
      ],
    );
  }
}

Color _cardColor(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF24282F)
        : const Color(0xFFF0F3F8);

class _RankingCard extends StatelessWidget {
  const _RankingCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;

    return Container(
      constraints: const BoxConstraints(minHeight: 164),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardColor(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withValues(alpha: 0.26)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: accent, size: 23),
          const SizedBox(height: 13),
          Text(
            title,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 3),
          Text(
            subtitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 11, color: muted),
          ),
          const SizedBox(height: 13),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text(
                '—',
                style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900),
              ),
              const SizedBox(width: 9),
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  'Скоро',
                  style: TextStyle(
                    color: accent,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActivityCard extends StatelessWidget {
  const _ActivityCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.accent,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: _cardColor(context),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: accent, size: 21),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
