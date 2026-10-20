import 'package:flutter/material.dart';

import '/app/router_app.dart';
import '/features/auth/view/login_screen.dart';
import '/features/profile/data/bars_subjects_storage.dart';
import '/features/profile/data/profile_avatar_storage.dart';
import '/features/profile/data/student_grades_storage.dart';
import '/features/profile/data/student_profile_storage.dart';
import '/features/schedule/data/group_storage.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final StudentProfileStorage _profileStorage = StudentProfileStorage();

  final StudentGradesStorage _gradesStorage = StudentGradesStorage();

  final BarsSubjectsStorage _subjectsStorage = BarsSubjectsStorage();

  final ProfileAvatarStorage _avatarStorage = ProfileAvatarStorage();

  final GroupStorage _groupStorage = GroupStorage();

  bool _loggingOut = false;

  Future<void> _logout() async {
    if (_loggingOut) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Выйти из аккаунта?'),
          content: const Text(
            'Данные профиля и оценки будут '
            'удалены с устройства. Для следующего '
            'входа потребуется снова войти через БАРС.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, false);
              },
              child: const Text('Отмена'),
            ),

            FilledButton(
              onPressed: () {
                Navigator.pop(context, true);
              },
              child: const Text('Выйти'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _loggingOut = true;
    });

    try {
      await Future.wait([
        _profileStorage.clearProfile(),
        _gradesStorage.clearGrades(),
        _subjectsStorage.clearSubjects(),
        _avatarStorage.clearAvatar(),
        _groupStorage.clearGroup(),
      ]);

      if (!mounted) {
        return;
      }

      Navigator.of(
        context,
      ).pushNamedAndRemoveUntil(AppRoutes.login, (route) => false);
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loggingOut = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось выйти из аккаунта')),
      );
    }
  }

  void _comingSoon(String text) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$text — добавим позже')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Настройки',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),

      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          const _SectionTitle(title: 'Общие'),

          _SettingsCard(
            children: [
              _SettingsTile(
                icon: Icons.notifications_outlined,
                title: 'Уведомления',
                subtitle: 'Настройки уведомлений',
                onTap: () {
                  _comingSoon('Уведомления');
                },
              ),

              const Divider(height: 1, indent: 56),

              _SettingsTile(
                icon: Icons.palette_outlined,
                title: 'Оформление',
                subtitle: 'Тема приложения',
                onTap: () {
                  _comingSoon('Оформление');
                },
              ),
            ],
          ),

          const SizedBox(height: 24),

          const _SectionTitle(title: 'Данные'),

          _SettingsCard(
            children: [
              _SettingsTile(
                icon: Icons.sync,
                title: 'Обновить данные из БАРС',
                subtitle: 'Повторно загрузить предметы и оценки из БАРС',
                onTap: () {
                  // Open BARS directly: /login goes through StartupGate
                  // and would skip it when the profile is cached.
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const LoginScreen(),
                    ),
                  );
                },
              ),
            ],
          ),

          const SizedBox(height: 24),

          const _SectionTitle(title: 'Приложение'),

          _SettingsCard(
            children: [
              _SettingsTile(
                icon: Icons.info_outline,
                title: 'О приложении',
                subtitle: 'Campus',
                onTap: () {
                  showAboutDialog(
                    context: context,
                    applicationName: 'Campus',
                    applicationVersion: '1.0.0',
                    children: const [Text('Приложение для студентов МЭИ.')],
                  );
                },
              ),
            ],
          ),

          const SizedBox(height: 32),

          SizedBox(
            height: 52,
            child: OutlinedButton.icon(
              onPressed: _loggingOut ? null : _logout,
              icon: _loggingOut
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.logout),
              label: Text(_loggingOut ? 'Выходим...' : 'Выйти из аккаунта'),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 10),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(children: children),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Icon(icon),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
    );
  }
}
