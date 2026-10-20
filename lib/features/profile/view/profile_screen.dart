import 'package:flutter/material.dart';

import '/features/auth/view/login_screen.dart';

import '../data/bars_control.dart';
import '../data/bars_subject.dart';
import '../data/bars_subjects_storage.dart';
import '../data/student_profile.dart';
import '../data/student_profile_storage.dart';

import 'settings_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final StudentProfileStorage _profileStorage = StudentProfileStorage();

  final BarsSubjectsStorage _subjectsStorage = BarsSubjectsStorage();

  StudentProfile? _profile;

  List<BarsSubject> _subjects = [];

  String? _selectedSemester;

  bool _loading = true;

  @override
  void initState() {
    super.initState();

    _load();
  }

  Future<void> _load() async {
    final profile = await _profileStorage.getProfile();

    final subjects = await _subjectsStorage.getSubjects();

    final semesters = _getSemesters(subjects);

    if (!mounted) {
      return;
    }

    setState(() {
      _profile = profile;
      _subjects = subjects;

      if (semesters.isNotEmpty) {
        if (_selectedSemester == null ||
            !semesters.contains(_selectedSemester)) {
          _selectedSemester = semesters.first;
        }
      }

      _loading = false;
    });
  }

  List<String> _getSemesters(List<BarsSubject> subjects) {
    final values = <String>[];

    for (final subject in subjects) {
      final semester = subject.semester.trim();

      if (semester.isNotEmpty && !values.contains(semester)) {
        values.add(semester);
      }
    }

    // The latest academic year must be shown first regardless of fetch order.
    values.sort((a, b) => b.compareTo(a));
    return values;
  }

  List<BarsSubject> get _visibleSubjects {
    if (_selectedSemester == null) {
      return [];
    }

    return _subjects
        .where((subject) => subject.semester == _selectedSemester)
        .toList();
  }

  String _value(String value) {
    return value.trim().isEmpty ? '—' : value.trim();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final profile = _profile;

    final semesters = _getSemesters(_subjects);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Профиль',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            onPressed: () async {
              await Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const SettingsScreen()));

              await _load();
            },
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 36),
          children: [
            if (profile != null) _ProfileHeader(profile: profile),

            const SizedBox(height: 24),

            Text(
              'Оценки БАРС',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            if (semesters.isNotEmpty) ...[
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: PopupMenuButton<String>(
                  tooltip: 'Выбрать семестр',
                  onSelected: (value) {
                    setState(() => _selectedSemester = value);
                  },
                  itemBuilder: (context) => semesters
                      .map((semester) => PopupMenuItem<String>(
                            value: semester,
                            child: Text(semester),
                          ))
                      .toList(),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.calendar_month_outlined, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          _selectedSemester ?? '',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.arrow_drop_down),
                      ],
                    ),
                  ),
                ),
              ),
            ],

            const SizedBox(height: 14),

            if (_visibleSubjects.isEmpty)
              const _EmptySubjects()
            else
              ..._visibleSubjects.map(
                (subject) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _SubjectCard(subject: subject),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.profile});

  final StudentProfile profile;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            profile.fullName,
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
          ),

          const SizedBox(height: 10),

          Row(
            children: [
              const Icon(Icons.groups_outlined, size: 18),

              const SizedBox(width: 6),

              Text(profile.group),

              const SizedBox(width: 18),

              const Icon(Icons.school_outlined, size: 18),

              const SizedBox(width: 6),

              Text('${profile.course} курс'),
            ],
          ),
        ],
      ),
    );
  }
}

class _SubjectCard extends StatelessWidget {
  const _SubjectCard({required this.subject});

  final BarsSubject subject;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        childrenPadding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
        shape: const Border(),
        collapsedShape: const Border(),
        title: Text(
          subject.name,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              if (subject.attestation.isNotEmpty) Text(subject.attestation),

              if (subject.credits.isNotEmpty) Text(subject.credits),
            ],
          ),
        ),
        trailing: _FinalBadge(value: subject.finalGrade),
        children: [
          if (subject.currentScore.isNotEmpty)
            _SummaryRow(
              title: 'Балл текущего контроля',
              value: subject.currentScore,
            ),

          if (subject.finalGrade.isNotEmpty)
            _SummaryRow(title: 'Итоговая оценка', value: subject.finalGrade),

          if (subject.controls.isNotEmpty &&
              (subject.currentScore.isNotEmpty ||
                  subject.finalGrade.isNotEmpty))
            const Divider(height: 24),

          for (var i = 0; i < subject.controls.length; i++) ...[
            _ControlRow(control: subject.controls[i]),

            if (i < subject.controls.length - 1) const Divider(height: 22),
          ],
        ],
      ),
    );
  }
}

class _ControlRow extends StatelessWidget {
  const _ControlRow({required this.control});

  final BarsControl control;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                control.title,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),

              const SizedBox(height: 5),

              Wrap(
                spacing: 12,
                children: [
                  if (control.weight.isNotEmpty)
                    Text(
                      'Вес: ${control.weight}%',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),

                  if (control.deadline.isNotEmpty)
                    Text(
                      control.deadline,
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(width: 12),

        _GradeBadge(value: control.grade),
      ],
    );
  }
}

class _GradeBadge extends StatelessWidget {
  const _GradeBadge({required this.value});

  final String value;

  @override
  Widget build(BuildContext context) {
    final raw = value.trim();
    final grade = RegExp(r'^[2-5](?=\s|$)').firstMatch(raw)?.group(0);
    final date = grade == null
        ? null
        : RegExp(r'\d{1,2}\.\d{1,2}\.\d{2,4}').firstMatch(raw)?.group(0);

    return Container(
      constraints: const BoxConstraints(minWidth: 46),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            grade ?? (raw.isEmpty ? '—' : raw),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
          ),
          if (date != null)
            Text(
              date,
              style: TextStyle(
                fontSize: 10,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            ),
        ],
      ),
    );
  }
}

class _FinalBadge extends StatelessWidget {
  const _FinalBadge({required this.value});

  final String value;

  @override
  Widget build(BuildContext context) {
    if (value.trim().isEmpty) {
      return const Icon(Icons.expand_more);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(value, style: const TextStyle(fontWeight: FontWeight.w900)),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.title, required this.value});

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(child: Text(title)),

          Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _EmptySubjects extends StatelessWidget {
  const _EmptySubjects();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Данные БАРС пока не загружены'),
          const SizedBox(height: 12),
          FilledButton.tonalIcon(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const LoginScreen(),
                ),
              );
            },
            icon: const Icon(Icons.sync),
            label: const Text('Загрузить оценки из БАРС'),
          ),
        ],
      ),
    );
  }
}
