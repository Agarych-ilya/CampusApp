import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '/app/router_app.dart';

import '/features/profile/data/bars_subject.dart';
import '/features/profile/data/bars_subjects_storage.dart';
import '/features/profile/data/student_profile.dart';
import '/features/profile/data/student_profile_storage.dart';

import '/features/schedule/data/group_storage.dart';

import '../data/bars_auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  static const String _barsUrl = 'https://bars.mpei.ru/bars_web/Auth/Menu';

  final BarsAuthService _bars = const BarsAuthService();

  final StudentProfileStorage _profileStorage = StudentProfileStorage();

  final GroupStorage _groupStorage = GroupStorage();

  final BarsSubjectsStorage _subjectsStorage = BarsSubjectsStorage();

  late final WebViewController _controller;

  Timer? _watchTimer;

  bool _barsOpening = true;

  bool _processing = false;

  bool _finished = false;

  bool _studentsClicked = false;

  bool _studentClicked = false;

  bool _readingStudyPage = false;

  Map<String, dynamic>? _studentRow;

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: _onPageStarted,
          onPageFinished: _onPageFinished,
          onWebResourceError: _onWebResourceError,
          onNavigationRequest: (NavigationRequest request) {
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(_barsUrl));

    _startWatcher();
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    _watchTimer?.cancel();

    super.dispose();
  }

  // ============================================================
  // WEBVIEW EVENTS
  // ============================================================

  void _onPageStarted(String url) {
    if (_finished) {
      return;
    }

    debugPrint('BARS page started');
  }

  void _onPageFinished(String url) {
    if (_finished) {
      return;
    }

    if (_barsOpening) {
      setState(() {
        _barsOpening = false;
      });
    }

    debugPrint('BARS page finished');

    // Не ждём следующего тика таймера.
    _checkBarsState();
  }

  void _onWebResourceError(WebResourceError error) {
    if (error.isForMainFrame == true) {
      debugPrint(
        'BARS main frame error: '
        '${error.errorCode}',
      );
    }
  }

  // ============================================================
  // WATCHER
  // ============================================================

  void _startWatcher() {
    _watchTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      _checkBarsState();
    });
  }

  Future<void> _checkBarsState() async {
    if (_finished || _readingStudyPage) {
      return;
    }

    try {
      // ========================================================
      // 1. AUTH/MENU -> "СТУДЕНТЫ"
      // ========================================================

      if (!_studentsClicked) {
        final hasStudents = await _bars.hasStudentsLink(_controller);

        if (hasStudents) {
          _setProcessing(true);

          debugPrint('BARS: students link found');

          final clicked = await _bars.clickStudents(_controller);

          if (clicked) {
            _studentsClicked = true;

            debugPrint('BARS: students clicked');
          }

          return;
        }
      }

      // ========================================================
      // 2. СТРАНИЦА "СТУДЕНТЫ"
      // ========================================================

      if (_studentsClicked && !_studentClicked) {
        final row = await _bars.getStudentRow(_controller);

        if (row != null && _isTrue(row['found'])) {
          _studentRow = row;

          debugPrint('BARS: student row found');

          final clicked = await _bars.clickStudentName(_controller);

          if (clicked) {
            _studentClicked = true;

            debugPrint('BARS: student name clicked');
          }

          return;
        }
      }

      // ========================================================
      // 3. УЧЕБНАЯ СТРАНИЦА УЖЕ ОТКРЫТА
      // ========================================================

      if (_studentClicked) {
        final ready = await _bars.hasStudyHeader(_controller);

        if (ready) {
          await _readStudyPage();
        }
      }
    } catch (e) {
      debugPrint('BARS watcher error: $e');
    }
  }

  // ============================================================
  // PARSE STUDY PAGE
  // ============================================================

  Future<void> _readStudyPage() async {
    if (_finished || _readingStudyPage) {
      return;
    }

    _readingStudyPage = true;

    _setProcessing(true);

    try {
      // --------------------------------------------------------
      // ПРОФИЛЬ
      // --------------------------------------------------------

      final studyProfile = await _bars.extractStudyProfile(_controller);

      if (studyProfile == null) {
        _readingStudyPage = false;

        return;
      }

      if (!_isTrue(studyProfile['ready'])) {
        _readingStudyPage = false;

        return;
      }

      debugPrint('BARS: study profile parsed');

      // --------------------------------------------------------
      // ПРЕДМЕТЫ / ОЦЕНКИ
      // --------------------------------------------------------

      final rawSubjects = await _bars.extractSubjects(_controller);

      final subjects = rawSubjects
          .map((item) => BarsSubject.fromMap(item))
          .where((subject) => subject.name.trim().isNotEmpty)
          .toList();

      debugPrint(
        'BARS SUBJECTS: '
        '${subjects.length}',
      );

      // --------------------------------------------------------
      // СОХРАНЯЕМ ПРЕДМЕТЫ
      // --------------------------------------------------------

      // Never erase previously fetched subjects on a temporary BARS error.
      if (subjects.isNotEmpty) {
        await _subjectsStorage.saveSubjects(subjects);
        debugPrint('BARS SUBJECTS SAVED: count=' + subjects.length.toString());
      } else {
        debugPrint('BARS SUBJECTS: empty result; previous cache preserved');
      }

      // --------------------------------------------------------
      
      // СОХРАНЯЕМ ПРОФИЛЬ
      // --------------------------------------------------------

      await _finish(studyProfile);
    } catch (e) {
      debugPrint('BARS read study page error: $e');

      _readingStudyPage = false;
    }
  }

  // ============================================================
  // SAVE PROFILE + GROUP
  // ============================================================

  Future<void> _finish(Map<String, dynamic> studyProfile) async {
    if (_finished) {
      return;
    }

    final row = _studentRow ?? const <String, dynamic>{};

    // ==========================================================
    // FIO
    // ==========================================================

    var fullName = _string(studyProfile['fullName']);

    if (fullName.isEmpty) {
      fullName = _string(row['fullName']);
    }

    // ==========================================================
    // RECORD BOOK
    // ==========================================================

    var recordBook = _string(studyProfile['recordBook']);

    if (recordBook.isEmpty) {
      recordBook = _string(row['recordBook']);
    }

    // ==========================================================
    // GROUP
    // ==========================================================

    var group = _string(studyProfile['group']);

    if (group.isEmpty) {
      group = _string(row['group']);
    }

    // ==========================================================
    // OTHER PROFILE DATA
    // ==========================================================

    final email = _string(studyProfile['email']);

    final course = _string(studyProfile['course']);

    final educationLevel = _string(studyProfile['educationLevel']);

    // Группа обязательна,
    // потому что от неё зависит расписание.
    if (group.isEmpty) {
      debugPrint('BARS: group is empty');

      _readingStudyPage = false;

      return;
    }

    final profile = StudentProfile(
      fullName: fullName,
      group: group,
      recordBook: recordBook,
      course: course,
      educationLevel: educationLevel,
      email: email,

      // Институт добавим позже.
      faculty: '',
    );

    try {
      // Профиль и группу сохраняем параллельно.
      await Future.wait([
        _profileStorage.saveProfile(profile),
        _groupStorage.saveGroup(group),
      ]);

      debugPrint('BARS: profile saved');

      debugPrint('BARS: group saved');

      _finished = true;

      _watchTimer?.cancel();

      if (!mounted) {
        return;
      }

      Navigator.of(
        context,
      ).pushNamedAndRemoveUntil(AppRoutes.main, (route) => false);
    } catch (e) {
      debugPrint('BARS save error: $e');

      _readingStudyPage = false;
    }
  }

  // ============================================================
  // HELPERS
  // ============================================================

  void _setProcessing(bool value) {
    if (!mounted) {
      return;
    }

    if (_processing == value) {
      return;
    }

    setState(() {
      _processing = value;
    });
  }

  bool _isTrue(dynamic value) {
    if (value == true) {
      return true;
    }

    return value?.toString().trim().toLowerCase() == 'true';
  }

  String _string(dynamic value) {
    return value?.toString().trim() ?? '';
  }

  // ============================================================
  // UI
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // ====================================================
          // WEBVIEW ВСЕГДА ОСТАЁТСЯ В ДЕРЕВЕ
          //
          // Это важно:
          // после авторизации BARS должен спокойно выполнить
          // переходы Студенты -> ФИО -> учебная страница.
          // ====================================================
          Positioned.fill(child: WebViewWidget(controller: _controller)),

          // ====================================================
          // ПЕРВИЧНОЕ ОТКРЫТИЕ BARS
          // ====================================================
          if (_barsOpening)
            const Positioned.fill(
              child: _BarsLoadingOverlay(title: 'Открываем БАРС...'),
            ),

          // ====================================================
          // СКРЫВАЕМ ВСЕ АВТОМАТИЧЕСКИЕ ПЕРЕХОДЫ
          // ====================================================
          if (!_barsOpening && _processing && !_finished)
            const Positioned.fill(
              child: _BarsLoadingOverlay(title: 'Загружаем данные...'),
            ),
        ],
      ),
    );
  }
}

// ================================================================
// LOADING OVERLAY
// ================================================================

class _BarsLoadingOverlay extends StatelessWidget {
  const _BarsLoadingOverlay({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Icon(
                    Icons.school_outlined,
                    size: 36,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),

                const SizedBox(height: 26),

                Text(
                  'Campus',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),

                const SizedBox(height: 12),

                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),

                const SizedBox(height: 24),

                const SizedBox(
                  width: 26,
                  height: 26,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
