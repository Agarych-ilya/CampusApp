import 'package:flutter/material.dart';

import '/core/theme/app_theme.dart';
import '../widgets/widgets.dart';

class ServicesScreen extends StatelessWidget {
  const ServicesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        children: [
          const SizedBox(height: 20),

          Text(
            'Сервисы',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),

          const SizedBox(height: 6),

          Text(
            'Быстрый доступ к полезным возможностям кампуса',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.55),
            ),
          ),

          const SizedBox(height: 18),

          const _SearchField(),

          const SizedBox(height: 26),

          _SectionHeader(
            title: 'Популярные',
            actionText: 'Все',
            onActionTap: () {},
          ),

          const SizedBox(height: 14),

          SizedBox(
            height: 150,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                PopularServiceCard(
                  title: 'Cloud Campus',
                  subtitle: 'Файлы и материалы',
                  icon: Icons.cloud_outlined,
                  iconColor: AppTheme.pink,
                  onTap: () {},
                ),

                const SizedBox(width: 14),

                // // PopularServiceCard(
                // //   title: 'Работа',
                // //   subtitle: 'Вакансии и стажировки',
                // //   icon: Icons.work_outline,
                // //   iconColor: const Color(0xFFE53935),
                // //   onTap: () {},
                // // ),

                // const SizedBox(width: 14),

                // PopularServiceCard(
                //   title: 'Курсы',
                //   subtitle: 'Обучение и практики',
                //   icon: Icons.school_outlined,
                //   iconColor: const Color(0xFF222222),
                //   onTap: () {},
                // ),

                // const SizedBox(width: 14),

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

          const SizedBox(height: 30),

          _SectionHeader(
            title: 'Сообщества',
            actionText: 'Добавить',
            onActionTap: () {},
          ),

          const SizedBox(height: 14),

          CommunityCard(
            title: 'Клуб любителей шахмат в МЭИ',
            description: 'Встречи, турниры и общение для студентов всех курсов',
            icon: Icons.groups_2_outlined,
            iconColor: AppTheme.pink,
            membersText: '128 участников',
            onTap: () {},
          ),

          const SizedBox(height: 14),

          CommunityCard(
            title: 'Кафедра МИЭФ',
            description: 'Неофициальный чат направления, новости и помощь',
            icon: Icons.forum_outlined,
            iconColor: const Color(0xFF3F51B5),
            membersText: '86 участников',
            onTap: () {},
          ),

          const SizedBox(height: 14),

          CommunityCard(
            title: 'Студенческие проекты',
            description: 'Команды, идеи, хакатоны и совместная разработка',
            icon: Icons.rocket_launch_outlined,
            iconColor: const Color(0xFF00A676),
            membersText: '54 участника',
            onTap: () {},
          ),

          const SizedBox(height: 28),

          const _PromoCard(),

          const SizedBox(height: 28),
        ],
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(
            Icons.search,
            color: theme.colorScheme.onSurface.withOpacity(0.45),
          ),

          const SizedBox(width: 10),

          Text(
            'Найти сервис или сообщество',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.42),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.actionText,
    required this.onActionTap,
  });

  final String title;
  final String actionText;
  final VoidCallback onActionTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w900,
          ),
        ),

        TextButton(
          onPressed: onActionTap,
          child: Text(
            actionText,
            style: const TextStyle(
              color: AppTheme.pink,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

class _PromoCard extends StatelessWidget {
  const _PromoCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.pink.withOpacity(0.10),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: AppTheme.pink.withOpacity(0.16),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.add_circle_outline, color: AppTheme.pink),
          ),

          const SizedBox(width: 14),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Не нашёл нужный сервис?',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  'Предложи идею, и мы добавим её в Campus App',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.58),
                    height: 1.25,
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
