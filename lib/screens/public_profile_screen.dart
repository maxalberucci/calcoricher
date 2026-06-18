import 'package:flutter/material.dart';
import '../gamification/achievements.dart';
import '../gamification/ranks.dart';
import '../models/user_model.dart';
import '../payments/payment_config.dart';
import '../theme/app_theme.dart';
import '../widgets/luxury_background.dart';
import '../widgets/profile_showcase.dart';

class PublicProfileScreen extends StatelessWidget {
  final UserModel user;
  final int leaderboardRank;
  final bool isCurrentUser;

  const PublicProfileScreen({
    super.key,
    required this.user,
    required this.leaderboardRank,
    required this.isCurrentUser,
  });

  @override
  Widget build(BuildContext context) {
    final rank = rankForSpent(user.totalSpentMinor);

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(isCurrentUser ? 'YOUR PUBLIC PROFILE' : 'PROFILE'),
      ),
      body: LuxuryBackground(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ProfileShowcase(user: user, showEmptyHint: false),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: _ProfileStatCard(
                            icon: Icons.leaderboard,
                            label: 'Leaderboard',
                            value: '#$leaderboardRank',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _ProfileStatCard(
                            icon: rank.icon,
                            label: 'Rank',
                            value: rank.name,
                            color: rank.color,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _ProfileStatCard(
                            icon: Icons.payments,
                            label: 'Spent',
                            value: PaymentConfig.format(user.totalSpentMinor),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _ProfileStatCard(
                            icon: Icons.lock_open,
                            label: 'Results',
                            value: '${user.unlockedResultsCount}',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _PublicAchievements(user: user),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileStatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _ProfileStatCard({
    required this.icon,
    required this.label,
    required this.value,
    this.color = AppTheme.gold,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.55), width: 0.5),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style:
                const TextStyle(color: AppTheme.textSecondary, fontSize: 10),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _PublicAchievements extends StatelessWidget {
  final UserModel user;
  const _PublicAchievements({required this.user});

  @override
  Widget build(BuildContext context) {
    final unlocked = kAchievements.where((a) => a.isUnlocked(user)).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'ACHIEVEMENTS',
              style: TextStyle(
                color: AppTheme.gold,
                fontSize: 11,
                letterSpacing: 2,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Spacer(),
            Text(
              '${unlocked.length} / ${kAchievements.length}',
              style: const TextStyle(
                color: AppTheme.gold,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (unlocked.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.divider),
            ),
            child: const Text(
              'No public achievements yet.',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          )
        else
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: unlocked
                .map((achievement) => _PublicAchievementBadge(
                      title: achievement.title,
                      icon: achievement.icon,
                      description: achievement.description,
                    ))
                .toList(),
          ),
      ],
    );
  }
}

class _PublicAchievementBadge extends StatelessWidget {
  final String title;
  final IconData icon;
  final String description;

  const _PublicAchievementBadge({
    required this.title,
    required this.icon,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: description,
      child: Container(
        width: 104,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: AppTheme.gold.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.gold),
        ),
        child: Column(
          children: [
            Icon(icon, color: AppTheme.gold, size: 26),
            const SizedBox(height: 8),
            Text(
              title,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                height: 1.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
