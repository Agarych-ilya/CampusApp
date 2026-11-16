import 'package:flutter/material.dart';

import '../../schedule/data/attendance_api.dart';
import '../data/bars_subject.dart';

/// Latest-semester numeric "Балл текущего контроля" from personal BARS.
class GradeScoreSnapshot {
  const GradeScoreSnapshot(this.semester, this.subjects);
  final String semester;
  final List<GradeRankingSubject> subjects;
  double get average => subjects.isEmpty ? 0 :
      subjects.map((x) => x.points).reduce((a, b) => a + b) / subjects.length;

  static GradeScoreSnapshot? parse(List<BarsSubject> records) {
    final semesters = <String, List<GradeRankingSubject>>{};
    final seen = <String, Set<String>>{};
    for (final subject in records) {
      final semester = subject.semester.trim();
      final name = subject.name.trim();
      final text = subject.currentScore.trim().replaceAll(',', '.');
      if (semester.isEmpty || semester.length > 96 || name.isEmpty ||
          name.length > 180 ||
          !RegExp(r'^\d{1,3}(?:\.\d{1,2})?$').hasMatch(text)) continue;
      final score = double.tryParse(text);
      if (score == null || score > 100 || score < 0) continue;
      final duplicate = seen.putIfAbsent(semester, () => {});
      if (!duplicate.add(name.toLowerCase().replaceAll('ё', 'е'))) continue;
      semesters.putIfAbsent(semester, () => []).add(
        GradeRankingSubject(name: name, points: score),
      );
    }
    if (semesters.isEmpty) return null;
    int order(String text) {
      final year = int.tryParse(RegExp(r'20\d{2}').firstMatch(text)?.group(0) ?? '') ?? 0;
      final spring = text.toLowerCase().contains('весен');
      return year * 10 + (spring ? 2 : 1);
    }
    final names = semesters.keys.toList()
      ..sort((a, b) {
        final first = order(b).compareTo(order(a));
        return first == 0 ? b.compareTo(a) : first;
      });
    return GradeScoreSnapshot(names.first, semesters[names.first]!.take(40).toList());
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

  @override
  void initState() {
    super.initState();
    _future = widget.api.gradeRanking(scope: widget.scope);
  }

  Future<void> _reload() async {
    setState(() => _future = widget.api.gradeRanking(scope: widget.scope));
    try { await _future; } catch (_) {}
  }

  Future<void> _submit() async {
    final snapshot = GradeScoreSnapshot.parse(widget.subjects);
    if (snapshot == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Нет текущих баллов БАРС. Сначала обнови оценки в профиле.'),
      ));
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Опубликовать баллы?'),
        content: Text(
          'Семестр: ${snapshot.semester}\n'
          'Предметов: ${snapshot.subjects.length}\n'
          'Средний текущий балл: ${snapshot.average.toStringAsFixed(2)}\n\n'
          'Твоё ФИО, группа и средний балл станут видны в рейтингах '
          'CampusApp. Баллы взяты из сохранённого БАРС на этом телефоне '
          'и не проверяются сервером университета. '
          'Ты сможешь удалить их в любой момент.',
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
                    label: const Text('Обновить баллы БАРС'),
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
                    label: const Text('Добавить мои баллы БАРС'),
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
                          SizedBox(width: 36, child: Text('${entry.place}',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w900,
                            ))),
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
