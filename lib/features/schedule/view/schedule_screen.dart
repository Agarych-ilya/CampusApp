import 'package:flutter/material.dart';
import '/features/services/booking/data/classroom_booking_api.dart';
import '/features/services/booking/view/classroom_booking_screen.dart';

import '../widgets/widgets.dart';
import '/core/theme/app_theme.dart';
import '../data/data.dart';
import '../data/lesson_group_access.dart';
import '../data/semester_week.dart';
import '../widgets/lesson_note_preview.dart';
import '/features/profile/data/student_profile_storage.dart';
import 'lesson_details_sheet.dart';

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({
    super.key,
    this.scheduleApi,
    this.groupStorage,
    this.bookingApi,
  });

  // Optional dependencies allow end-to-end widget tests without an MPEI server.
  final ScheduleApi? scheduleApi;
  final GroupStorage? groupStorage;
  final ClassroomBookingApi? bookingApi;

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  static const int _initialWeekPage = 5000;
  late final ScheduleApi _scheduleApi;
  late final GroupStorage _groupStorage;
  final Map<int, Future<List<ScheduleLesson>>> _weekFutures = {};

  String? _groupName;
  String? _profileGroup;
  String? _initializationError;
  bool _isInitializing = true;
  bool _changingGroup = false;
  int _notesRevision = 0;
  Set<String> _bookableRooms = bookableClassrooms.toSet();
  late DateTime _selectedDate;
  late DateTime _anchorWeek;
  late PageController _weekController;
  int _currentWeekPage = _initialWeekPage;

  @override
  void initState() {
    super.initState();
    _scheduleApi = widget.scheduleApi ?? ScheduleApi();
    _groupStorage = widget.groupStorage ?? GroupStorage();
    _selectedDate = DateTime.now();
    _anchorWeek = _getWeekStart(_selectedDate);
    _weekController = PageController(initialPage: _initialWeekPage);
    _initialize();
    _loadBookableRooms();
  }

  /// Refresh server catalogue without blocking or changing timetable loading.
  Future<void> _loadBookableRooms() async {
    // Widget tests inject an offline fake booking API.
    if (widget.bookingApi != null) return;
    final api = ClassroomBookingApi();
    try {
      final rooms = await api.bookableRooms();
      if (mounted) setState(() => _bookableRooms = rooms);
    } catch (_) {
      // Keep the known demo rooms until the backend becomes reachable.
    } finally {
      api.dispose();
    }
  }

  @override
  void dispose() {
    _weekController.dispose();
    super.dispose();
  }

  Future<void> _initialize() async {
    try {
      final group = await _groupStorage.getScheduleGroup();
      final profile = await StudentProfileStorage().getProfile();
      if (group == null || group.isEmpty) {
        throw StateError(
          'Учебная группа не найдена. Войди через БАРС, '
          'чтобы получить свою группу.',
        );
      }
      if (!mounted) return;
      setState(() {
        _groupName = group;
        _profileGroup = profile?.group;
        _initializationError = null;
        _isInitializing = false;
        _weekFutures.clear();
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _initializationError = error.toString();
        _isInitializing = false;
      });
    }
  }

  DateTime _getWeekStart(DateTime date) => DateTime(
        date.year,
        date.month,
        date.day - date.weekday + 1,
      );

  DateTime _startForPage(int page) => DateTime(
        _anchorWeek.year,
        _anchorWeek.month,
        _anchorWeek.day + (page - _initialWeekPage) * 7,
      );

  int _pageForDate(DateTime date) {
    // UTC calendar math avoids daylight-saving gaps in local DateTime.
    final monday = _getWeekStart(date);
    final target = DateTime.utc(monday.year, monday.month, monday.day);
    final anchor = DateTime.utc(
      _anchorWeek.year,
      _anchorWeek.month,
      _anchorWeek.day,
    );
    return _initialWeekPage + target.difference(anchor).inDays ~/ 7;
  }

  DateTime _dateForPage(int page) {
    final monday = _startForPage(page);
    return DateTime(monday.year, monday.month,
        monday.day + _selectedDate.weekday - 1);
  }

  Future<List<ScheduleLesson>> _lessonsForPage(int page) {
    final group = _groupName;
    if (group == null || group.isEmpty) {
      return Future.error(StateError('Группа не определена'));
    }
    return _weekFutures.putIfAbsent(
      page,
      () => _scheduleApi.getWeekSchedule(
        group: group,
        selectedDate: _startForPage(page),
      ),
    );
  }

  void _onWeekChanged(int page) {
    if (page == _currentWeekPage) return;
    final newStart = _startForPage(page);
    final weekday = _selectedDate.weekday;
    setState(() {
      _currentWeekPage = page;
      _selectedDate = DateTime(
        newStart.year,
        newStart.month,
        newStart.day + weekday - 1,
      );
    });
  }

  void _selectDate(DateTime date) {
    final nextPage = _pageForDate(date);
    if (nextPage < 0 || nextPage > 10000) return;
    setState(() {
      _selectedDate = date;
      _currentWeekPage = nextPage;
    });
    if (_weekController.hasClients &&
        _weekController.page?.round() != nextPage) {
      _weekController.jumpToPage(nextPage);
    }
  }

  void _refreshWeekSchedule() {
    final group = _groupName;
    if (group == null || group.isEmpty) return;
    final page = _currentWeekPage;
    setState(() {
      _weekFutures[page] = _scheduleApi.getWeekSchedule(
        group: group,
        selectedDate: _startForPage(page),
        forceRefresh: true,
      );
    });
  }

  Future<void> _chooseGroup() async {
    if (_changingGroup) return;
    final group = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      showDragHandle: true,
      builder: (context) => ScheduleGroupPicker(
        api: _scheduleApi,
        currentGroup: _groupName ?? '',
      ),
    );
    if (!mounted || group == null) return;
    final selectedGroup = group.trim();
    if (selectedGroup.isEmpty || selectedGroup == _groupName) return;

    // Verify and fetch the selected group's timetable BEFORE changing
    // its label or persisting it. This prevents a wrong group name
    // from being displayed above the previous group's lessons.
    final page = _currentWeekPage;
    setState(() => _changingGroup = true);
    try {
      final lessons = await _scheduleApi.getWeekSchedule(
        group: selectedGroup,
        selectedDate: _startForPage(page),
        forceRefresh: true,
      );
      if (!mounted) return;
      await _groupStorage.saveScheduleGroup(selectedGroup);
      if (!mounted) return;

      setState(() {
        _groupName = selectedGroup;
        _weekFutures.clear();
        // Use the verified result instead of showing a stale old future.
        _weekFutures[page] = Future.value(lessons);
        _changingGroup = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _changingGroup = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Не удалось открыть расписание группы $selectedGroup: $error',
          ),
        ),
      );
    }
  }

  Future<void> _showMonthCalendar() async {
    await showDialog<void>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.08),
      builder: (dialogContext) => Dialog(
        alignment: Alignment.topLeft,
        insetPadding: EdgeInsets.only(
          left: 20,
          top: MediaQuery.of(dialogContext).padding.top + 52,
          right: 20,
          bottom: 24,
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: MonthCalendarPopup(
          selectedDate: _selectedDate,
          onDateSelected: (date) {
            _selectDate(date);
            Navigator.of(dialogContext).pop();
          },
        ),
      ),
    );
  }

  bool _isSameDate(DateTime first, DateTime second) =>
      first.year == second.year &&
      first.month == second.month &&
      first.day == second.day;

  List<ScheduleLesson> _lessonsForDay(
    List<ScheduleLesson> lessons,
    DateTime date,
  ) {
    final filtered = lessons.where((lesson) {
      final parsed = lesson.parsedDate;
      return parsed != null && _isSameDate(parsed, date);
    }).toList();
    filtered.sort((a, b) => a.time.compareTo(b.time));
    return filtered;
  }

  Future<void> _openLessonDetails(ScheduleLesson lesson) async {
    final group = _groupName;
    final profile = await StudentProfileStorage().getProfile();
    if (!mounted || group == null || group.isEmpty ||
        !canOpenOwnLessonDetails(
          profileGroup: profile?.group,
          viewedGroup: group,
        )) {
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (sheetContext) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.9,
        minChildSize: 0.55,
        maxChildSize: 0.97,
        builder: (context, controller) => LessonDetailsSheet(
          group: group,
          lesson: lesson,
          scrollController: controller,
          onNotesChanged: () {
            if (mounted) setState(() => _notesRevision++);
          },
        ),
      ),
    );
    // Changes made in the modal are visible on the underlying cards.
    if (mounted) setState(() => _notesRevision++);
  }

  Future<void> _openClassroomBooking(ScheduleLesson lesson) async {
    // The same rule as lesson details: other groups cannot interact with
    // Only a student's own group and server-supported rooms are bookable.
    if (!_bookableRooms.contains(classroomCodeFromLesson(lesson.room))) return;
    final profile = await StudentProfileStorage().getProfile();
    if (!mounted || !canOpenOwnLessonDetails(
      profileGroup: profile?.group,
      viewedGroup: _groupName,
    )) return;
    final date = lesson.parsedDate;
    if (date == null) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ClassroomBookingScreen(
          api: widget.bookingApi,
          lessonDate: date,
          lessonTime: lesson.time,
          initialRoom: lesson.room,
          allowedRooms: _bookableRooms,
        ),
      ),
    );
  }

  Widget _weekPage(BuildContext context, int page) {
    final theme = Theme.of(context);
    final date = _dateForPage(page);

    return FutureBuilder<List<ScheduleLesson>>(
      key: ValueKey('week-${_groupName ?? ''}-$page'),
      future: _lessonsForPage(page),
      builder: (context, snapshot) {
        final all = snapshot.data ?? const <ScheduleLesson>[];
        final todayLessons = _lessonsForDay(all, date);
        final isOwnGroup = canOpenOwnLessonDetails(
          profileGroup: _profileGroup,
          viewedGroup: _groupName,
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 6),
            WeekDaysRow(
              selectedDate: date,
              weekLessons: all,
              onDateSelected: _selectDate,
            ),
            const SizedBox(height: 13),
            Row(
              children: [
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      _formatSelectedDate(date),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.62),
                      ),
                    ),
                  ),
                ),
                Text(
                  semesterWeekLabel(date),
                  key: const ValueKey('schedule-semester-week'),
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                Expanded(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_changingGroup)
                          const Padding(
                            padding: EdgeInsets.only(right: 4),
                            child: SizedBox(
                              height: 14,
                              width: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        Flexible(
                          child: TextButton.icon(
                            key: const ValueKey('schedule-group-search'),
                            onPressed: _changingGroup ? null : _chooseGroup,
                            icon: const Icon(Icons.search_rounded, size: 17),
                            label: Text(
                              _groupName ?? 'Группа',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4, vertical: 7,
                              ),
                              visualDensity: VisualDensity.compact,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 15),
            Expanded(
              child: snapshot.connectionState == ConnectionState.waiting
                  ? const Center(
                      child: CircularProgressIndicator(color: AppTheme.pink),
                    )
                  : snapshot.hasError
                      ? ScheduleMessage(
                          icon: Icons.error_outline,
                          title: 'Не удалось загрузить расписание',
                          subtitle: snapshot.error.toString(),
                          buttonText: 'Повторить',
                          onPressed: _refreshWeekSchedule,
                        )
                      : todayLessons.isEmpty
                          ? const ScheduleMessage(
                              icon: Icons.event_busy_outlined,
                              title: 'Занятий нет',
                              subtitle: 'Для выбранного дня расписание не найдено',
                            )
                          : RefreshIndicator(
                              onRefresh: () async {
                                _refreshWeekSchedule();
                                try {
                                  await _lessonsForPage(page);
                                } catch (_) {
                                  // FutureBuilder shows the error message.
                                }
                              },
                              child: ListView(
                                physics: const AlwaysScrollableScrollPhysics(),
                                children: [
                                  if (_scheduleApi.showingOfflineCopy)
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 12),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.cloud_off_outlined,
                                              size: 18, color: Colors.amber),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              'Нет связи с сервером. '
                                              'Показано сохранённое расписание.',
                                              style: theme.textTheme.bodySmall,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  for (final lesson in todayLessons)
                                    LessonCard(
                                      onTap: isOwnGroup
                                          ? () => _openLessonDetails(lesson)
                                          : null,
                                      onBookSeat: isOwnGroup &&
                                              _bookableRooms.contains(
                                                classroomCodeFromLesson(lesson.room),
                                              )
                                          ? () => _openClassroomBooking(lesson)
                                          : null,
                                      footer: isOwnGroup && _groupName != null
                                          ? LessonNotePreview(
                                              group: _groupName!,
                                              lesson: lesson,
                                              revision: _notesRevision,
                                            )
                                          : null,
                                      time: lesson.time,
                                      subject: lesson.subject,
                                      type: lesson.type,
                                      room: lesson.room,
                                      teacher: lesson.teacher,
                                    ),
                                ],
                              ),
                            ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (_isInitializing) {
      return const SafeArea(
        child: Center(child: CircularProgressIndicator(color: AppTheme.pink)),
      );
    }
    if (_initializationError != null) {
      return SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 48),
                const SizedBox(height: 14),
                const Text('Не удалось загрузить группу'),
                const SizedBox(height: 8),
                Text(_initializationError!, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () {
                    setState(() {
                      _isInitializing = true;
                      _initializationError = null;
                    });
                    _initialize();
                  },
                  child: const Text('Повторить'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 15),
            Row(
              children: [
                InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: _showMonthCalendar,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 7),
                    child: Row(
                      children: [
                        Text(
                          _getWeekDayName(_selectedDate),
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.keyboard_arrow_down, size: 19),
                      ],
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  _getMonthName(_selectedDate),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                IconButton(
                  tooltip: 'Обновить расписание',
                  onPressed: _refreshWeekSchedule,
                  icon: const Icon(Icons.refresh, size: 21),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: PageView.builder(
                key: ValueKey('schedule-pages-${_groupName ?? ''}'),
                controller: _weekController,
                physics: _changingGroup
                    ? const NeverScrollableScrollPhysics()
                    : const PageScrollPhysics(),
                onPageChanged: _onWeekChanged,
                itemBuilder: (context, page) => _weekPage(context, page),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getWeekDayName(DateTime date) {
    const weekDays = [
      'Понедельник',
      'Вторник',
      'Среда',
      'Четверг',
      'Пятница',
      'Суббота',
      'Воскресенье',
    ];

    return weekDays[date.weekday - 1];
  }

  String _getMonthName(DateTime date) {
    const months = [
      'Январь',
      'Февраль',
      'Март',
      'Апрель',
      'Май',
      'Июнь',
      'Июль',
      'Август',
      'Сентябрь',
      'Октябрь',
      'Ноябрь',
      'Декабрь',
    ];

    return months[date.month - 1];
  }

  String _formatSelectedDate(DateTime date) {
    const months = [
      'января',
      'февраля',
      'марта',
      'апреля',
      'мая',
      'июня',
      'июля',
      'августа',
      'сентября',
      'октября',
      'ноября',
      'декабря',
    ];

    return '${date.day} ${months[date.month - 1]}';
  }
}


