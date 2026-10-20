import 'package:flutter/material.dart';

import '/core/theme/app_theme.dart';
import '/features/services/cloud/view/cloud_screen.dart';
import '../widgets/widgets.dart';

class ServicesScreen extends StatelessWidget {
  const ServicesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Сервисы',
          style: TextStyle(
            fontWeight: FontWeight.w900,
          ),
        ),
        centerTitle: false,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            20,
            16,
            20,
            32,
          ),
          children: [
            Text(
              'Популярные сервисы',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),

            const SizedBox(height: 16),

            SizedBox(
              height: 160,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  PopularServiceCard(
                    title: 'Cloud Campus',
                    subtitle: 'Файлы и материалы',
                    icon: Icons.cloud_outlined,
                    iconColor: AppTheme.pink,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) =>
                              const CloudScreen(),
                        ),
                      );
                    },
                  ),

                  const SizedBox(width: 14),

                  // Можно вернуть позже:
                  //
                  // const SizedBox(width: 14),
                  //
                  // PopularServiceCard(
                  //   title: 'Работа',
                  //   subtitle: 'Вакансии и стажировки',
                  //   icon: Icons.work_outline,
                  //   iconColor: const Color(0xFFE53935),
                  //   onTap: () {},
                  // ),
                  //
                  // const SizedBox(width: 14),
                  //
                  // PopularServiceCard(
                  //   title: 'Курсы',
                  //   subtitle: 'Обучение и практики',
                  //   icon: Icons.school_outlined,
                  //   iconColor: const Color(0xFF222222),
                  //   onTap: () {},
                  // ),
                  //
                  // const SizedBox(width: 14),
                  //
                  // PopularServiceCard(
                  //   title: 'Документы',
                  //   subtitle: 'Справки и заявления',
                  //   icon: Icons.description_outlined,
                  //   iconColor: const Color(0xFF3F51B5),
                  //   onTap: () {},
                  // ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            Text(
              'Все сервисы',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),

            const SizedBox(height: 16),

            _ServiceTile(
              title: 'Cloud Campus',
              subtitle: 'Хранение учебных файлов',
              icon: Icons.cloud_outlined,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) =>
                        const CloudScreen(),
                  ),
                );
              },
            ),

            const SizedBox(height: 12),

            _ServiceTile(
              title: 'Расписание',
              subtitle: 'Учебное расписание',
              icon: Icons.calendar_month_outlined,
              onTap: () {},
            ),

            const SizedBox(height: 12),

            _ServiceTile(
              title: 'Кампус',
              subtitle: 'Корпуса и навигация',
              icon: Icons.location_city_outlined,
              onTap: () {},
            ),
          ],
        ),
      ),
    );
  }
}

class _ServiceTile extends StatelessWidget {
  const _ServiceTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: AppTheme.pink.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  icon,
                  color: AppTheme.pink,
                ),
              ),

              const SizedBox(width: 14),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),

                    const SizedBox(height: 4),

                    Text(
                      subtitle,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface
                            .withOpacity(0.5),
                      ),
                    ),
                  ],
                ),
              ),

              const Icon(
                Icons.chevron_right,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
