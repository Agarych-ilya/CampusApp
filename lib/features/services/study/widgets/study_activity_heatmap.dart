import 'dart:math' as math;

import 'package:flutter/material.dart';

import '/features/services/style/service_palette.dart';
import '../data/study_activity_storage.dart';

/// Exactly 17 calendar weeks (one semester), Monday through Sunday.
class StudyActivityHeatmap extends StatelessWidget {
  const StudyActivityHeatmap({
    super.key,
    required this.activity,
  });

  static const int semesterWeeks = 17;
  static const _dayNames = ['Пн', '', 'Ср', '', 'Пт', '', 'Вс'];

  final Map<DateTime, StudyDayActivity> activity;

  Color _cellColor(int count, ThemeData theme) {
    if (count == 0) return theme.colorScheme.surfaceContainerHighest;
    if (count <= 2) return ServicePalette.heat1;
    if (count <= 5) return ServicePalette.heat2;
    if (count <= 10) return ServicePalette.heat3;
    return ServicePalette.heat4;
  }

  String _date(DateTime day) =>
      day.day.toString().padLeft(2, '0') + '.' +
      day.month.toString().padLeft(2, '0') + '.' +
      day.year.toString();

  void _showDay(
    BuildContext context,
    DateTime date,
    StudyDayActivity info,
  ) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text(
          _date(date) + ': ' + info.correctAnswers.toString() +
          ' правильных ответов, ' + info.tests.toString() + ' тестов, ' +
          info.flashcardRounds.toString() + ' кругов карточек',
        ),
      ));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final today = studyCalendarDay(DateTime.now());

    // Start on Monday, 16 full weeks before the current calendar week.
    // The last (seventeenth) column contains the current week. Future
    // days are blank rather than represented as days without activity.
    final monday = DateTime(
      today.year,
      today.month,
      today.day - today.weekday + 1 - (semesterWeeks - 1) * 7,
    );

    var correct = 0;
    var tests = 0;
    var rounds = 0;
    for (var i = 0; i < semesterWeeks * 7; i++) {
      final date = DateTime(monday.year, monday.month, monday.day + i);
      if (date.isAfter(today)) break;
      final entry = activity[date];
      correct += entry?.correctAnswers ?? 0;
      tests += entry?.tests ?? 0;
      rounds += entry?.flashcardRounds ?? 0;
    }
    final streak = studyCurrentStreak(activity, today: today);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withOpacity(0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.calendar_month_outlined,
                  color: ServicePalette.accent, size: 20),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  'Активность · 17 недель',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w900),
                ),
              ),
              const Icon(Icons.local_fire_department_outlined,
                  color: ServicePalette.amber, size: 17),
              const SizedBox(width: 4),
              Text('$streak дн.',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  )),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Чем ярче клетка, тем больше правильных ответов.',
            style: TextStyle(color: muted, fontSize: 12),
          ),
          const SizedBox(height: 17),
          LayoutBuilder(builder: (context, constraints) {
            const gap = 3.0;
            final size = math.min(
              15.0,
              math.max(9.0,
                (constraints.maxWidth - 24 -
                    (semesterWeeks - 1) * gap) / semesterWeeks,
              ),
            );

            Widget cell(DateTime date) {
              if (date.isAfter(today)) {
                return SizedBox(width: size, height: size);
              }
              final info = activity[date] ?? const StudyDayActivity();
              return Tooltip(
                message: _date(date) + ': ' +
                    info.correctAnswers.toString() + ' правильных, ' +
                    info.tests.toString() + ' тестов',
                child: Semantics(
                  label: _date(date) + ', ' +
                      info.correctAnswers.toString() +
                      ' правильных ответов',
                  button: true,
                  child: InkWell(
                    onTap: () => _showDay(context, date, info),
                    borderRadius: BorderRadius.circular(3),
                    child: Container(
                      width: size,
                      height: size,
                      decoration: BoxDecoration(
                        color: _cellColor(info.correctAnswers, theme),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                ),
              );
            }

            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 7),
                    child: Column(
                      children: [
                        for (var row = 0; row < 7; row++) ...[
                          SizedBox(
                            height: size,
                            width: 17,
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                _dayNames[row],
                                style: TextStyle(color: muted, fontSize: 9),
                              ),
                            ),
                          ),
                          if (row < 6) const SizedBox(height: gap),
                        ],
                      ],
                    ),
                  ),
                  for (var week = 0; week < semesterWeeks; week++) ...[
                    Column(
                      key: ValueKey('semester-week-$week'),
                      children: [
                        for (var row = 0; row < 7; row++) ...[
                          cell(DateTime(monday.year, monday.month,
                              monday.day + week * 7 + row)),
                          if (row < 6) const SizedBox(height: gap),
                        ],
                      ],
                    ),
                    if (week < semesterWeeks - 1)
                      const SizedBox(width: gap),
                  ],
                ],
              ),
            );
          }),
          const SizedBox(height: 14),
          Text(
            '$correct верно · $tests тестов · $rounds кругов карточек',
            style: TextStyle(color: muted, fontSize: 11,
                fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 4,
            runSpacing: 5,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text('Меньше', style: TextStyle(color: muted, fontSize: 10)),
              for (final level in [0, 1, 3, 6, 11])
                Container(
                  height: 12,
                  width: 12,
                  decoration: BoxDecoration(
                    color: _cellColor(level, theme),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              Text('Больше', style: TextStyle(color: muted, fontSize: 10)),
            ],
          ),
        ],
      ),
    );
  }
}
