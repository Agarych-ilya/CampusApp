import 'package:flutter/material.dart';

import '/features/services/style/service_palette.dart';

import '../data/study_activity_storage.dart';
import '../widgets/study_activity_heatmap.dart';

/// Compact, scrollable test result, designed for small Android screens.
class StudyResultsContent extends StatelessWidget {
  const StudyResultsContent({
    super.key,
    required this.correctAnswers,
    required this.totalAnswers,
    required this.onRetry,
    required this.activity,
    this.activityError,
  });

  final int correctAnswers;
  final int totalAnswers;
  final VoidCallback onRetry;
  final Map<DateTime, StudyDayActivity> activity;
  final String? activityError;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final percentage = totalAnswers == 0
        ? 0
        : (correctAnswers / totalAnswers * 100).round();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(0, 6, 0, 14),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 510),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainer,
                  borderRadius: BorderRadius.circular(23),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 58,
                      height: 58,
                      decoration: BoxDecoration(
                        color: ServicePalette.accent.withOpacity(0.13),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: const Icon(Icons.emoji_events_outlined,
                          color: ServicePalette.accent, size: 34),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Тест завершён',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '$correctAnswers из $totalAnswers верно',
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: ServicePalette.accent,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '$percentage% правильных ответов',
                      style: TextStyle(color: muted, fontSize: 12),
                    ),
                    const SizedBox(height: 17),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: LinearProgressIndicator(
                        value: totalAnswers == 0
                            ? 0.0
                            : correctAnswers / totalAnswers,
                        minHeight: 7,
                        color: ServicePalette.accent,
                        backgroundColor:
                            theme.colorScheme.surfaceContainerHighest,
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: onRetry,
                        icon: const Icon(Icons.refresh_rounded, size: 19),
                        label: const Text('Пройти ещё раз'),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          foregroundColor: ServicePalette.accentOnDark,
                          backgroundColor: ServicePalette.accent,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              if (activityError != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    activityError!,
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.error,
                    ),
                  ),
                ),
              StudyActivityHeatmap(activity: activity),
              const SizedBox(height: 13),
              Text(
                'Суммируются правильные ответы за каждый день, '
                'включая повторные тесты. Нажми на клетку, чтобы '
                'узнать результат за дату.',
                style: TextStyle(
                  color: muted,
                  fontSize: 12,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
