import 'package:flutter/material.dart';

import '../data/community_api.dart';

class CommunityAvatar extends StatelessWidget {
  const CommunityAvatar({
    super.key,
    required this.community,
    this.size = 60,
  });

  final CommunityData community;
  final double size;

  static IconData iconFor(String kind) => switch (kind) {
    'chat' => Icons.forum_rounded,
    'campus' => Icons.account_balance_rounded,
    'news' => Icons.campaign_rounded,
    'study' => Icons.school_rounded,
    'club' => Icons.groups_rounded,
    'events' => Icons.celebration_rounded,
    _ => Icons.groups_rounded,
  };

  static List<Color> colorsFor(String kind) => switch (kind) {
    'chat' => const [Color(0xFF20BDEB), Color(0xFF1679C9)],
    'campus' => const [Color(0xFF8874FD), Color(0xFF5F42C9)],
    'news' => const [Color(0xFFFB6195), Color(0xFFD82A6F)],
    'study' => const [Color(0xFFFFB14F), Color(0xFFF16C40)],
    'club' => const [Color(0xFF62DABA), Color(0xFF139986)],
    'events' => const [Color(0xFF8BA5FF), Color(0xFF5355C9)],
    _ => const [Color(0xFF8874FD), Color(0xFF5F42C9)],
  };

  @override
  Widget build(BuildContext context) {
    final colors = colorsFor(community.iconKind);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
        borderRadius: BorderRadius.circular(size * 0.29),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -size * 0.14,
            right: -size * 0.08,
            child: Container(
              width: size * 0.66,
              height: size * 0.66,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Center(
            child: Icon(
              iconFor(community.iconKind),
              color: Colors.white,
              size: size * 0.47,
            ),
          ),
        ],
      ),
    );
  }
}
