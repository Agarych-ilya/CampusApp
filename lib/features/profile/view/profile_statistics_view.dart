import 'dart:math' as math;

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
    final stats = _GradeStats(subjects);
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
          'Диаграммы',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 12),
        _GradeDistributionCard(stats: stats),
        const SizedBox(height: 12),
        _GradeCoverageCard(stats: stats),
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
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _ActivityCard(
                icon: Icons.insights_outlined,
                label: 'Средняя оценка',
                value: stats.average,
                accent: const Color(0xFF8B8CF8),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _ActivityCard(
                icon: Icons.school_outlined,
                label: 'Итоговых оценок',
                value: stats.finalCount.toString(),
                accent: const Color(0xFF60A5FA),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          'Данные только по загруженным семестрам БАРС. '
          'Средняя оценка не учитывает веса работ; '
          'зачёты без числовой отметки не включены.',
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


/// Only numeric activity marks (2–5) are included in the charts.
/// Missing results and non-numeric pass/fail records are not treated as zero.
class _GradeStats {
  _GradeStats(List<BarsSubject> subjects) {
    final pattern = RegExp(r'^\s*([2-5])(?=\s|$)');
    for (final subject in subjects) {
      totalControls += subject.controls.length;
      if (pattern.hasMatch(subject.finalGrade)) finalCount++;

      for (final control in subject.controls) {
        final match = pattern.firstMatch(control.grade);
        if (match == null) continue;
        final mark = int.parse(match.group(1)!);
        distribution[mark] = (distribution[mark] ?? 0) + 1;
        gradedControls++;
        gradeSum += mark;
      }
    }
  }

  final Map<int, int> distribution = {5: 0, 4: 0, 3: 0, 2: 0};
  int totalControls = 0;
  int gradedControls = 0;
  int finalCount = 0;
  int gradeSum = 0;

  double get covered => totalControls == 0 ? 0 : gradedControls / totalControls;

  String get average => gradedControls == 0
      ? '—'
      : (gradeSum / gradedControls).toStringAsFixed(2).replaceAll('.', ',');
}

class _GradeDistributionCard extends StatelessWidget {
  const _GradeDistributionCard({required this.stats});
  final _GradeStats stats;

  @override
  Widget build(BuildContext context) {
    const colors = <int, Color>{
      5: Color(0xFF32B28D),
      4: Color(0xFF5FA8FF),
      3: Color(0xFFE6B460),
      2: Color(0xFFE1747F),
    };
    final segments = <_RingPiece>[
      for (final grade in [5, 4, 3, 2])
        _RingPiece(
          value: (stats.distribution[grade] ?? 0).toDouble(),
          color: colors[grade]!,
        ),
    ];

    return _ChartPanel(
      title: 'Распределение оценок',
      subtitle: 'Числовые отметки за контрольные мероприятия',
      child: Row(
        children: [
          _Donut(
            pieces: segments,
            value: stats.gradedControls.toString(),
            label: 'оценок',
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              children: [
                for (final grade in [5, 4, 3, 2])
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: _ChartLegend(
                      color: colors[grade]!,
                      title: 'Оценка ' + grade.toString(),
                      count: (stats.distribution[grade] ?? 0).toString(),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GradeCoverageCard extends StatelessWidget {
  const _GradeCoverageCard({required this.stats});
  final _GradeStats stats;

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF8B8CF8);
    final percent = (stats.covered * 100).round();

    return _ChartPanel(
      title: 'Доля оценённых работ',
      subtitle: 'Мероприятия с выставленной оценкой 2–5',
      child: Row(
        children: [
          _Donut(
            pieces: [
              _RingPiece(
                value: stats.gradedControls.toDouble(),
                color: accent,
              ),
            ],
            denominator: stats.totalControls.toDouble(),
            value: percent.toString() + '%',
            label: 'оценено',
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              children: [
                _ChartLegend(
                  color: accent,
                  title: 'С оценкой',
                  count: stats.gradedControls.toString(),
                ),
                const SizedBox(height: 18),
                _ChartLegend(
                  color: _ringTrack(context),
                  title: 'Без оценки 2–5',
                  count: (stats.totalControls - stats.gradedControls)
                      .toString(),
                ),
                const SizedBox(height: 12),
                Text(
                  'Всего работ: ' + stats.totalControls.toString(),
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChartPanel extends StatelessWidget {
  const _ChartPanel({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: _cardColor(context),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 5),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 11,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 20),
          child,
        ],
      ),
    );
  }
}

class _ChartLegend extends StatelessWidget {
  const _ChartLegend({
    required this.color,
    required this.title,
    required this.count,
  });

  final Color color;
  final String title;
  final String count;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          count,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
        ),
      ],
    );
  }
}

class _RingPiece {
  const _RingPiece({required this.value, required this.color});
  final double value;
  final Color color;
}

Color _ringTrack(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF343B49)
        : const Color(0xFFDDE4EE);

class _Donut extends StatelessWidget {
  const _Donut({
    required this.pieces,
    required this.value,
    required this.label,
    this.denominator,
  });

  final List<_RingPiece> pieces;
  final String value;
  final String label;
  final double? denominator;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 120,
      height: 120,
      child: CustomPaint(
        painter: _DonutPainter(
          pieces: pieces,
          track: _ringTrack(context),
          denominator: denominator,
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value,
                style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w900),
              ),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  const _DonutPainter({
    required this.pieces,
    required this.track,
    required this.denominator,
  });

  final List<_RingPiece> pieces;
  final Color track;
  final double? denominator;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 14.0;
    final radius = (math.min(size.width, size.height) - stroke) / 2;
    final rect = Rect.fromCircle(
      center: size.center(Offset.zero),
      radius: radius,
    );

    final background = Paint()
      ..color = track
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    canvas.drawCircle(size.center(Offset.zero), radius, background);

    final included = pieces.fold<double>(0, (s, p) => s + p.value);
    final total = denominator ?? included;
    if (total <= 0) return;

    var start = -math.pi / 2;
    for (final piece in pieces) {
      if (piece.value <= 0) continue;
      final sweep = math.pi * 2 * (piece.value / total).clamp(0.0, 1.0);
      final gap = denominator == null && pieces.length > 1 ? 0.024 : 0.0;
      final drawSweep = math.max(0.0, sweep - gap);

      if (drawSweep > 0) {
        canvas.drawArc(
          rect,
          start + gap / 2,
          drawSweep,
          false,
          Paint()
            ..color = piece.color
            ..style = PaintingStyle.stroke
            ..strokeWidth = stroke,
        );
      }
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) {
    if (oldDelegate.track != track ||
        oldDelegate.denominator != denominator ||
        oldDelegate.pieces.length != pieces.length) {
      return true;
    }
    for (var i = 0; i < pieces.length; i++) {
      if (oldDelegate.pieces[i].value != pieces[i].value ||
          oldDelegate.pieces[i].color != pieces[i].color) {
        return true;
      }
    }
    return false;
  }
}
