import 'dart:math' as math;
import 'package:flutter/material.dart';

import '/core/theme/app_theme.dart';
import '../data/study_activity_storage.dart';

/// Seven rows (Monday–Sunday), one column per calendar week.
class StudyActivityHeatmap extends StatefulWidget {
  const StudyActivityHeatmap({
    super.key,
    required this.activity,
    this.initialDays = 84,
  });

  final Map<DateTime, StudyDayActivity> activity;
  final int initialDays;

  @override
  State<StudyActivityHeatmap> createState() => _StudyActivityHeatmapState();
}

class _StudyActivityHeatmapState extends State<StudyActivityHeatmap> {
  late int _days;
  static const periods = [7, 30, 84];
  static const dayNames = ['Пн', '', 'Ср', '', 'Пт', '', 'Вс'];

  @override
  void initState() {
    super.initState();
    _days = periods.contains(widget.initialDays) ? widget.initialDays : 84;
  }

  Color _level(int value, ThemeData theme) {
    if (value == 0) return theme.colorScheme.surfaceContainerHighest;
    if (value <= 2) return const Color(0xFF5B314B);
    if (value <= 5) return const Color(0xFF97416E);
    if (value <= 10) return const Color(0xFFCE3D83);
    return const Color(0xFFFF0B83);
  }

  String _date(DateTime day) =>
      day.day.toString().padLeft(2, '0') + '.' +
      day.month.toString().padLeft(2, '0') + '.' +
      day.year.toString();

  void _show(DateTime day, StudyDayActivity activity) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text(
          _date(day) + ': ' + activity.correctAnswers.toString() +
          ' правильных ответов, ' + activity.tests.toString() + ' тестов',
        ),
      ));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final today = studyCalendarDay(DateTime.now());
    final start = DateTime(today.year, today.month, today.day - _days + 1);
    final monday = DateTime(
      start.year, start.month, start.day - start.weekday + 1,
    );
    final sunday = DateTime(
      today.year, today.month, today.day + 7 - today.weekday,
    );
    // Use UTC for counting calendar days across daylight-saving changes.
    final columns = (DateTime.utc(sunday.year, sunday.month, sunday.day)
            .difference(DateTime.utc(monday.year, monday.month, monday.day))
            .inDays +
        1) ~/ 7;
    var correct = 0;
    var tests = 0;
    for (var i = 0; i < _days; i++) {
      final day = DateTime(start.year, start.month, start.day + i);
      final entry = widget.activity[day];
      correct += entry?.correctAnswers ?? 0;
      tests += entry?.tests ?? 0;
    }
    final streak = studyCurrentStreak(widget.activity, today: today);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(21),
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
                  color: AppTheme.pink, size: 20),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  'Активность',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w900),
                ),
              ),
              const Icon(Icons.local_fire_department_outlined,
                  color: AppTheme.pink, size: 17),
              const SizedBox(width: 4),
              Text('$streak дн.',
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 7),
          Text(
            'Ярче день — больше правильных ответов.',
            style: TextStyle(color: muted, fontSize: 12),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              for (final days in periods)
                InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => setState(() => _days = days),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 11, vertical: 7),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      color: _days == days
                          ? AppTheme.pink.withOpacity(0.15)
                          : theme.colorScheme.surfaceContainerHighest,
                      border: Border.all(
                        color: _days == days
                            ? AppTheme.pink.withOpacity(0.6)
                            : Colors.transparent,
                      ),
                    ),
                    child: Text(
                      days == 84 ? '12 недель' : '$days дней',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: _days == days ? AppTheme.pink : muted,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          LayoutBuilder(builder: (context, constraints) {
            const gap = 4.0;
            final size = math.min(17.0, math.max(
              12.0, (constraints.maxWidth - 28 - gap * columns) /
                  math.max(1, columns),
            ));

            Widget tile(DateTime day) {
              if (day.isBefore(start) || day.isAfter(today)) {
                return SizedBox(width: size, height: size);
              }
              final info =
                  widget.activity[day] ?? const StudyDayActivity();
              return Tooltip(
                message: _date(day) + ': ' +
                    info.correctAnswers.toString() + ' правильных, ' +
                    info.tests.toString() + ' тестов',
                child: Semantics(
                  label: _date(day) + ', ' +
                      info.correctAnswers.toString() + ' правильных ответов',
                  button: true,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(4),
                    onTap: () => _show(day, info),
                    child: Container(
                      width: size,
                      height: size,
                      decoration: BoxDecoration(
                        color: _level(info.correctAnswers, theme),
                        borderRadius: BorderRadius.circular(4),
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
                    padding: const EdgeInsets.only(right: 8),
                    child: Column(
                      children: [
                        for (var row = 0; row < 7; row++) ...[
                          SizedBox(
                            width: 19,
                            height: size,
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Text(dayNames[row],
                                  style: TextStyle(
                                      color: muted, fontSize: 9)),
                            ),
                          ),
                          if (row < 6) const SizedBox(height: gap),
                        ],
                      ],
                    ),
                  ),
                  for (var week = 0; week < columns; week++) ...[
                    Column(
                      children: [
                        for (var row = 0; row < 7; row++) ...[
                          tile(DateTime(monday.year, monday.month,
                              monday.day + week * 7 + row)),
                          if (row < 6) const SizedBox(height: gap),
                        ],
                      ],
                    ),
                    if (week + 1 < columns) const SizedBox(width: gap),
                  ],
                ],
              ),
            );
          }),
          const SizedBox(height: 15),
          Text(
            '$correct верно · $tests тестов',
            style: TextStyle(
              color: muted,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 4,
            runSpacing: 5,
            children: [
              Text('Меньше', style: TextStyle(color: muted, fontSize: 10)),
              for (final level in [0, 1, 3, 6, 11])
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: _level(level, theme),
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
