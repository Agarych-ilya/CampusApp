import 'package:flutter/material.dart';
import 'dart:typed_data';

import '../../schedule/data/attendance_api.dart';
import '../data/bars_subject.dart';

/// Weighted assessment marks (2–5); currentScore is intentionally ignored.
class GradeScoreSnapshot {
  const GradeScoreSnapshot(this.semester, this.subjects, this.missingWeights);
  final String semester;
  final List<GradeRankingSubject> subjects;
  final int missingWeights;

  double get weightedSum => subjects.fold<double>(
    0, (sum, item) => sum + item.points * item.weight,
  );
  double get totalWeight => subjects.fold<double>(
    0, (sum, item) => sum + item.weight,
  );
  double get average => totalWeight <= 0 ? 0 : weightedSum / totalWeight;

  static double? _mark(String raw) {
    final match = RegExp(r'^\s*([2-5])(?:[.,](\d{1,2}))?(?=\s|$|\()')
        .firstMatch(raw);
    if (match == null) return null;
    final text = match.group(1)! +
      (match.group(2) == null ? '' : '.${match.group(2)}');
    final value = double.tryParse(text);
    return value != null && value >= 2 && value <= 5 ? value : null;
  }

  static double? _weight(String raw) {
    final normalized = raw.trim().replaceAll(' ', '')
        .replaceAll('%', '').replaceAll(',', '.');
    if (!RegExp(r'^\d+(?:\.\d{1,3})?$').hasMatch(normalized)) return null;
    final value = double.tryParse(normalized);
    return value != null && value > 0 && value <= 100 ? value : null;
  }

  static GradeScoreSnapshot? parse(List<BarsSubject> records) {
    final marks = <GradeRankingSubject>[];
    var unweighted = 0;
    for (var subjectIndex = 0; subjectIndex < records.length; subjectIndex++) {
      final subject = records[subjectIndex];
      for (var index = 0; index < subject.controls.length; index++) {
        final control = subject.controls[index];
        final grade = _mark(control.grade);
        if (grade == null) continue;
        final weight = _weight(control.weight);
        if (weight == null) {
          unweighted++;
          continue;
        }
        final descriptor =
            '${subject.semester} · ${subject.name} · ${control.title}';
        final prefix = descriptor.length > 153
            ? descriptor.substring(0, 153)
            : descriptor;
        marks.add(GradeRankingSubject(
          name: '$prefix #${subjectIndex + 1}.${index + 1}',
          points: grade,
          weight: weight,
        ));
      }
    }
    if (marks.isEmpty) return null;
    return GradeScoreSnapshot('Все семестры', marks, unweighted);
  }
}

class GradeRankingScreen extends StatefulWidget {
  const GradeRankingScreen({
    required this.scope, required this.subjects, required this.api, super.key,
  });
  final String scope;
  final List<BarsSubject> subjects;
  final AttendanceApi api;

  @override
  State<GradeRankingScreen> createState() => _GradeRankingScreenState();
}

class _GradeRankingScreenState extends State<GradeRankingScreen> {
  late Future<GradeRanking> _future;
  bool _busy = false;
  final Map<String,Future<Uint8List?>> _photos = {};

  @override
  void initState() {
    super.initState();
    _future = widget.api.gradeRanking(scope: widget.scope);
  }

  Future<void> _reload() async {
    setState(() {
      _future = widget.api.gradeRanking(scope: widget.scope);
    });
    try { await _future; } catch (_) {}
  }

  Future<void> _submit() async {
    final snapshot = GradeScoreSnapshot.parse(widget.subjects);
    if (snapshot == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Нет оценок с корректными весами. Проверь работы БАРС в профиле.'),
      ));
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Опубликовать баллы?'),
        content: Text(
          'Период: ${snapshot.semester}\n'
          'Оценённых работ с весом: ${snapshot.subjects.length}\n'
          'Сумма (оценка × вес): ${snapshot.weightedSum.toStringAsFixed(2)}\n'
          'Сумма весов: ${snapshot.totalWeight.toStringAsFixed(2)}\n'
          'Средневзвешенная оценка: ${snapshot.average.toStringAsFixed(2)}\n'
          'Работ без корректного веса: ${snapshot.missingWeights}\n\n'
          'В рейтинг публикуется средневзвешенная оценка по работам БАРС '
          '(от 2 до 5), а также твоё ФИО и группа. '
          'Сервер не проверяет оценки через официальный БАРС. '
          'Публикацию можно удалить.',

        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: const Text('Опубликовать'),
          ),
        ],
      ),
    );
    if (!mounted || ok != true) return;
    setState(() => _busy = true);
    try {
      await widget.api.publishGradePoints(snapshot.semester, snapshot.subjects);
      if (mounted) await _reload();
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось опубликовать: $error')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _remove() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Удалить мои баллы?'),
        content: const Text(
          'Они исчезнут из обоих рейтингов. '
          'Сохранённые оценки в профиле останутся.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (!mounted || ok != true) return;
    setState(() => _busy = true);
    try {
      await widget.api.withdrawGradePoints();
      if (mounted) await _reload();
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось удалить: $error')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _rankingAvatar(GradeRankingEntry entry,ThemeData theme) {
    final muted = theme.colorScheme.onSurfaceVariant;
    final initials = entry.displayName.trim().split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty).take(2)
        .map((part) => part.substring(0,1).toUpperCase()).join();
    Widget placeholder() => CircleAvatar(
      radius: 20,
      backgroundColor: theme.colorScheme.primary.withOpacity(0.13),
      child: Text(initials.isEmpty ? '•' : initials,
        style: TextStyle(color: muted,fontSize: 13,
          fontWeight: FontWeight.w800)),
    );
    if (entry.avatarId == null || entry.avatarId!.isEmpty) {
      return placeholder();
    }
    return FutureBuilder<Uint8List?>(
      future: _photos.putIfAbsent(
        entry.avatarId!, () => widget.api.rankingAvatar(entry.avatarId!),
      ),
      builder: (context,snapshot) {
        final data = snapshot.data;
        if (data == null || data.isEmpty) return placeholder();
        return CircleAvatar(
          key: ValueKey('ranking-server-avatar-${entry.avatarId}'),
          radius: 20,
          backgroundImage: MemoryImage(data),
          onBackgroundImageError: (_, __) {},
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final stream = widget.scope == 'stream';
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return Scaffold(
      appBar: AppBar(title: Text(stream ? 'На потоке' : 'В группе')),
      body: FutureBuilder<GradeRanking>(
        future: _future,
        builder: (context, data) {
          if (data.connectionState == ConnectionState.waiting &&
              data.data == null) {
            return const Center(child: CircularProgressIndicator());
          }
          final ranking = data.data;
          if (ranking == null) return Center(child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Не удалось получить рейтинг'),
              TextButton(onPressed: _reload, child: const Text('Повторить')),
            ],
          ));
          return RefreshIndicator(
            onRefresh: _reload,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 45),
              children: [
                Text('Рейтинг по баллам',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  )),
                const SizedBox(height: 5),
                Text(stream ? 'Все группы с «А-»'
                    : 'Группа ${ranking.group}',
                  style: TextStyle(color: muted)),
                const SizedBox(height: 17),
                Container(
                  padding: const EdgeInsets.all(19),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Моё место', style: TextStyle(color: muted)),
                      const SizedBox(height: 6),
                      Text(ranking.myPlace == null ? '—' :
                        '${ranking.myPlace} / ${ranking.participants}',
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                        )),
                      Text('Участников: ${ranking.participants} из ${ranking.total}',
                        style: theme.textTheme.bodyMedium),
                      if (ranking.semester != null)
                        Text(ranking.semester!,
                          style: TextStyle(color: muted, fontSize: 12)),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                if (ranking.published) ...[
                  FilledButton.icon(
                    key: const ValueKey('score-ranking-update'),
                    onPressed: _busy ? null : _submit,
                    icon: const Icon(Icons.sync),
                    label: const Text('Пересчитать оценки'),
                  ),
                  const SizedBox(height: 6),
                  OutlinedButton.icon(
                    key: const ValueKey('score-ranking-delete'),
                    onPressed: _busy ? null : _remove,
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Убрать мои баллы'),
                  ),
                ] else
                  FilledButton.icon(
                    key: const ValueKey('score-ranking-publish'),
                    onPressed: _busy ? null : _submit,
                    icon: const Icon(Icons.add_chart),
                    label: const Text('Опубликовать среднюю оценку'),
                  ),
                const SizedBox(height: 11),
                Text(
                  'Неофициальный рейтинг среди добровольных участников. '
                  'Сравнивается средний балл текущего контроля за семестр. '
                  'Баллы предоставляют сами студенты.',
                  style: TextStyle(color: muted, fontSize: 12, height: 1.4),
                ),
                const SizedBox(height: 24),
                Text('Таблица мест', style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                )),
                const SizedBox(height: 12),
                if (ranking.entries.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 22),
                    child: Text(
                      'Пока никто не опубликовал баллы. '
                      'Список группы сам по себе оценок не содержит.',
                      style: TextStyle(color: muted),
                    ),
                  ),
                for (final entry in ranking.entries)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Container(
                      key: ValueKey('score-ranking-${entry.group}-${entry.displayName}'),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: entry.mine
                            ? theme.colorScheme.primary.withOpacity(.16)
                            : theme.colorScheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(17),
                      ),
                      child: Row(
                        children: [
                          SizedBox(width: 28, child: Text('${entry.place}',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w900,
                            ))),
                          _rankingAvatar(entry,theme),
                          const SizedBox(width: 10),
                          Expanded(child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(entry.displayName, maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                )),
                              if (stream) Text(entry.group,
                                style: TextStyle(color: muted, fontSize: 12)),
                              if (entry.mine) Text('Вы',
                                style: TextStyle(
                                  color: theme.colorScheme.primary,
                                  fontWeight: FontWeight.w800,
                                )),
                            ],
                          )),
                          const SizedBox(width: 8),
                          Text(entry.averageScore.toStringAsFixed(2),
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w900,
                            )),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
