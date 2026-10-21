import 'dart:io';

import 'package:flutter/material.dart';

import '/features/auth/view/login_screen.dart';

import '../data/bars_control.dart';
import '../data/bars_subject.dart';
import '../data/bars_subjects_storage.dart';
import '../data/profile_avatar_storage.dart';
import '../data/student_profile.dart';
import '../data/student_profile_storage.dart';
import 'profile_statistics_view.dart';
import 'settings_screen.dart';

/// Newest academic year first. Within the same year spring is after autumn
/// chronologically, so the spring term is displayed first.
int _compareSemesters(String a, String b) {
  final yearPattern = RegExp(r'(\d{4})\s*/\s*(\d{4})');

  int year(String value) =>
      int.tryParse(yearPattern.firstMatch(value)?.group(1) ?? '') ?? -1;

  int term(String value) {
    final lower = value.toLowerCase();
    if (lower.contains('весен')) return 2;
    if (lower.contains('осен')) return 1;
    return 0;
  }

  final yearComparison = year(b).compareTo(year(a));
  if (yearComparison != 0) return yearComparison;

  final termComparison = term(b).compareTo(term(a));
  if (termComparison != 0) return termComparison;

  return b.compareTo(a);
}

String? _gradeNumber(String raw) {
  final match = RegExp(r'^\s*([2-5])(?=\s|$)').firstMatch(raw);
  return match?.group(1);
}

Color _subjectSurface(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF202535)
        : const Color(0xFFF0F3FB);

Color _subjectInnerSurface(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF2A3144)
        : const Color(0xFFE4EAF6);

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

enum _AvatarAction { choose, delete }

class _ProfileScreenState extends State<ProfileScreen> {
  final StudentProfileStorage _profileStorage = StudentProfileStorage();
  final BarsSubjectsStorage _subjectsStorage = BarsSubjectsStorage();
  final ProfileAvatarStorage _avatarStorage = ProfileAvatarStorage();

  StudentProfile? _profile;
  List<BarsSubject> _subjects = [];
  File? _avatar;
  String? _selectedSemester;
  bool _loading = true;
  bool _changingAvatar = false;
  int _activePage = 0;
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);
    _load();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _switchPage(int page) {
    _pageController.animateToPage(
      page,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeInOutCubic,
    );
  }

  Future<void> _load() async {
    final profile = await _profileStorage.getProfile();
    final subjects = await _subjectsStorage.getSubjects();
    final avatar = await _avatarStorage.getAvatar();
    final semesters = _getSemesters(subjects);

    if (!mounted) return;

    setState(() {
      _profile = profile;
      _subjects = subjects;
      _avatar = avatar;

      if (semesters.isEmpty) {
        _selectedSemester = null;
      } else if (_selectedSemester == null ||
          !semesters.contains(_selectedSemester)) {
        _selectedSemester = semesters.first;
      }
      _loading = false;
    });
  }

  List<String> _getSemesters(List<BarsSubject> subjects) {
    final semesters = <String>{};
    for (final subject in subjects) {
      if (subject.semester.trim().isNotEmpty) {
        semesters.add(subject.semester.trim());
      }
    }
    return semesters.toList()..sort(_compareSemesters);
  }

  List<BarsSubject> get _visibleSubjects {
    if (_selectedSemester == null) return [];
    return _subjects
        .where((subject) => subject.semester.trim() == _selectedSemester)
        .toList();
  }

  Future<void> _editAvatar() async {
    if (_changingAvatar) return;

    final action = await showModalBottomSheet<_AvatarAction>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Выбрать фото из галереи'),
                onTap: () => Navigator.pop(
                  sheetContext,
                  _AvatarAction.choose,
                ),
              ),
              if (_avatar != null)
                ListTile(
                  leading: const Icon(Icons.delete_outline),
                  title: const Text('Удалить фотографию'),
                  onTap: () => Navigator.pop(
                    sheetContext,
                    _AvatarAction.delete,
                  ),
                ),
            ],
          ),
        ),
      ),
    );

    if (!mounted || action == null) return;

    setState(() => _changingAvatar = true);
    try {
      if (action == _AvatarAction.delete) {
        await _avatarStorage.clearAvatar();
        if (mounted) setState(() => _avatar = null);
      } else {
        final image = await _avatarStorage.pickAndSaveAvatar();
        if (mounted && image != null) setState(() => _avatar = image);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Не удалось сохранить фотографию. Выбери другое изображение.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _changingAvatar = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final semesters = _getSemesters(_subjects);
    final visibleSubjects = _visibleSubjects;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Профиль',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            tooltip: 'Настройки',
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const SettingsScreen(),
                ),
              );
              await _load();
            },
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_profile != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
              child: _ProfileHeader(
                profile: _profile!,
                avatar: _avatar,
                changingAvatar: _changingAvatar,
                onAvatarTap: _editAvatar,
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 10),
            child: _ProfilePagerTabs(
              selectedPage: _activePage,
              onSelected: _switchPage,
            ),
          ),
          Expanded(
            child: PageView(
              controller: _pageController,
              onPageChanged: (index) {
                if (mounted) setState(() => _activePage = index);
              },
              children: [
                // Default view: swipe left to open Statistics.
                RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    key: const PageStorageKey('profile_grades'),
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(18, 10, 18, 36),
                    children: [
                      Row(
                        children: [
                          Text(
                            'Оценки БАРС',
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const Spacer(),
                          if (visibleSubjects.isNotEmpty)
                            Text(
                              '${visibleSubjects.length} предм.',
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (semesters.isNotEmpty)
                        _SemesterSelector(
                          selected: _selectedSemester ?? '',
                          semesters: semesters,
                          onSelected: (value) =>
                              setState(() => _selectedSemester = value),
                        ),
                      const SizedBox(height: 16),
                      if (visibleSubjects.isEmpty)
                        const _EmptySubjects()
                      else
                        ...visibleSubjects.asMap().entries.map(
                          (entry) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _SubjectCard(
                              subject: entry.value,
                              index: entry.key,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                // Swipe right on this page to return to Grades.
                RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    key: const PageStorageKey('profile_statistics'),
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(18, 10, 18, 36),
                    children: [
                      ProfileStatisticsView(
                        profile: _profile,
                        subjects: _subjects,
                      ),
                    ],
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
 
class _ProfilePagerTabs extends StatelessWidget {
  const _ProfilePagerTabs({
    required this.selectedPage,
    required this.onSelected,
  });

  final int selectedPage;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final background = dark
        ? const Color(0xFF222630)
        : const Color(0xFFE9EDF3);
    final active = dark
        ? const Color(0xFF343D50)
        : const Color(0xFFFFFFFF);
    final activeText = dark
        ? const Color(0xFFB9D7FF)
        : const Color(0xFF225D9D);

    Widget tab(int index, IconData icon, String title) {
      final selected = selectedPage == index;
      return Expanded(
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => onSelected(index),
            borderRadius: BorderRadius.circular(13),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(vertical: 11),
              decoration: BoxDecoration(
                color: selected ? active : Colors.transparent,
                borderRadius: BorderRadius.circular(13),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    icon,
                    size: 17,
                    color: selected
                        ? activeText
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 7),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                      color: selected
                          ? activeText
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          tab(0, Icons.school_outlined, 'Оценки'),
          tab(1, Icons.bar_chart_rounded, 'Статистика'),
        ],
      ),
    );
  }
}
class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.profile,
    required this.avatar,
    required this.onAvatarTap,
    required this.changingAvatar,
  });

  final StudentProfile profile;
  final File? avatar;
  final VoidCallback onAvatarTap;
  final bool changingAvatar;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final surface = dark
        ? const Color(0xFF282332)
        : const Color(0xFFFFEDF5);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(42),
            onTap: changingAvatar ? null : onAvatarTap,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                ClipOval(
                  child: SizedBox(
                    width: 74,
                    height: 74,
                    child: avatar == null
                        ? ColoredBox(
                            color: scheme.primary.withValues(alpha: 0.15),
                            child: Icon(
                              Icons.person_rounded,
                              size: 40,
                              color: scheme.primary,
                            ),
                          )
                        : Image.file(
                            avatar!,
                            key: ValueKey(avatar!.path),
                            fit: BoxFit.cover,
                            width: 74,
                            height: 74,
                            errorBuilder: (_, _, _) => const Icon(
                              Icons.person_rounded,
                              size: 38,
                            ),
                          ),
                  ),
                ),
                Positioned(
                  right: -1,
                  bottom: -1,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: scheme.primary,
                      shape: BoxShape.circle,
                      border: Border.all(color: surface, width: 2),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(5),
                      child: const Icon(
                        Icons.camera_alt_outlined,
                        size: 14,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile.fullName,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 7,
                  children: [
                    _ProfileMeta(
                      icon: Icons.groups_2_outlined,
                      text: profile.group,
                    ),
                    _ProfileMeta(
                      icon: Icons.school_outlined,
                      text: profile.course.isEmpty
                          ? 'Курс не указан'
                          : '${profile.course} курс',
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                InkWell(
                  onTap: changingAvatar ? null : onAvatarTap,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text(
                      changingAvatar ? 'Сохраняем фото…' : 'Изменить фото',
                      style: TextStyle(
                        fontSize: 12,
                        color: scheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
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

class _ProfileMeta extends StatelessWidget {
  const _ProfileMeta({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16),
        const SizedBox(width: 5),
        Text(text, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}

class _SemesterSelector extends StatelessWidget {
  const _SemesterSelector({
    required this.selected,
    required this.semesters,
    required this.onSelected,
  });

  final String selected;
  final List<String> semesters;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: PopupMenuButton<String>(
        tooltip: 'Выбрать семестр',
        onSelected: onSelected,
        itemBuilder: (context) => semesters
            .map(
              (semester) => PopupMenuItem<String>(
                value: semester,
                child: Row(
                  children: [
                    Expanded(child: Text(semester)),
                    if (semester == selected)
                      Icon(
                        Icons.check_rounded,
                        size: 18,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                  ],
                ),
              ),
            )
            .toList(),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            color: _subjectInnerSurface(context),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.calendar_month_outlined, size: 17),
              const SizedBox(width: 8),
              Text(
                selected,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 6),
              const Icon(Icons.keyboard_arrow_down, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

class _SubjectCard extends StatelessWidget {
  const _SubjectCard({required this.subject, required this.index});

  final BarsSubject subject;
  final int index;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: _subjectSurface(context),
        borderRadius: BorderRadius.circular(21),
      ),
      child: Column(
        children: [
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              // Each tile needs a distinct PageStorage entry. Without this
              // key, it may read the ListView scroll offset (double) as the
              // tile expansion state (bool), crashing the whole grades page.
              key: PageStorageKey<String>(
                'bars_subject:${subject.semester}:${subject.name}:$index',
              ),
              shape: const Border(),
              collapsedShape: const Border(),
              tilePadding: const EdgeInsets.fromLTRB(16, 13, 14, 13),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              title: Text(
                subject.name,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  height: 1.25,
                ),
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        if (subject.attestation.trim().isNotEmpty)
                          _MetadataPill(text: subject.attestation),
                        if (subject.credits.trim().isNotEmpty)
                          _MetadataPill(text: subject.credits),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _SubjectGradePreview(subject: subject),
                  ],
                ),
              ),
              children: [
                const Divider(height: 18),
                if (subject.currentScore.trim().isNotEmpty)
                  _SummaryRow(
                    title: 'Балл текущего контроля',
                    value: subject.currentScore,
                  ),
                if (subject.finalGrade.trim().isNotEmpty)
                  _SummaryRow(
                    title: 'Итоговая оценка',
                    value: subject.finalGrade,
                  ),
                if (subject.controls.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      'Контрольных мероприятий пока нет',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  )
                else
                  ...subject.controls.asMap().entries.map(
                    (entry) => Padding(
                      padding: const EdgeInsets.only(bottom: 9),
                      child: _ControlDetails(control: entry.value),
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

class _MetadataPill extends StatelessWidget {
  const _MetadataPill({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: _subjectInnerSurface(context),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _SubjectGradePreview extends StatelessWidget {
  const _SubjectGradePreview({required this.subject});

  final BarsSubject subject;

  @override
  Widget build(BuildContext context) {
    final grades = <String>[];

    final finalGrade =
        _gradeNumber(subject.finalGrade) ?? subject.finalGrade.trim();
    if (finalGrade.isNotEmpty) grades.add(finalGrade);

    for (final control in subject.controls) {
      final grade = _gradeNumber(control.grade) ?? control.grade.trim();
      if (grade.isNotEmpty) grades.add(grade);
    }

    if (grades.isEmpty) {
      return Text(
        'Оценок пока нет',
        style: TextStyle(
          fontSize: 12,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      );
    }

    // Only the marks; labels, dates and current points are in expanded details.
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ...grades.take(8).map((grade) => _GradeDot(value: grade)),
        if (grades.length > 8)
          _MetadataPill(text: '+${grades.length - 8}'),
      ],
    );
  }
}

class _GradeDot extends StatelessWidget {
  const _GradeDot({required this.value});

  final String value;

  @override
  Widget build(BuildContext context) {
    final normalized = _gradeNumber(value) ?? value.trim();

    Color color;
    switch (normalized) {
      case '5':
        color = const Color(0xFF57C084);
        break;
      case '4':
        color = const Color(0xFF5FA8FF);
        break;
      case '3':
        color = const Color(0xFFF0B35A);
        break;
      case '2':
        color = const Color(0xFFE26D6D);
        break;
      default:
        color = const Color(0xFFD98DA9);
        break;
    }

    return Container(
      constraints: const BoxConstraints(minWidth: 42, minHeight: 34),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.18),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        normalized,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w900,
          color: color,
        ),
      ),
    );
  }
}

class _ControlDetails extends StatelessWidget {
  const _ControlDetails({required this.control});

  final BarsControl control;

  @override
  Widget build(BuildContext context) {
    final grade = _gradeNumber(control.grade);
    final date = RegExp(r'\d{1,2}\.\d{1,2}\.\d{2,4}')
        .firstMatch(control.grade)
        ?.group(0);
    final gradeText = grade ?? control.grade.trim();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _subjectInnerSurface(context),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  control.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 7),
                if (control.weight.trim().isNotEmpty)
                  Text(
                    'Вес: ${control.weight}%',
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                if (control.deadline.trim().isNotEmpty)
                  Text(
                    control.deadline,
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                if (date != null)
                  Text(
                    'Получена: $date',
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 9),
          if (gradeText.isNotEmpty)
            _GradeDot(value: gradeText)
          else
            Text(
              '—',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
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
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(child: Text(title)),
          const SizedBox(width: 8),
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
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: _subjectSurface(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Данные БАРС пока не загружены'),
          const SizedBox(height: 10),
          FilledButton.tonalIcon(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const LoginScreen(),
                ),
              );
            },
            icon: const Icon(Icons.sync),
            label: const Text('Загрузить оценки'),
          ),
        ],
      ),
    );
  }
}
