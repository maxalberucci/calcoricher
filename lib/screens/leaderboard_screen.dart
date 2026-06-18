import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/user_model.dart';
import '../payments/payment_config.dart';
import '../gamification/ranks.dart';
import '../providers/user_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/luxury_background.dart';
import '../widgets/user_avatar.dart';
import 'public_profile_screen.dart';

class LeaderboardScreen extends StatelessWidget {
  const LeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final leaderboard = context.watch<UserProvider>().leaderboard;
    final currentId = context.watch<UserProvider>().currentUser?.id;

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: AppBar(title: const Text('LEADERBOARD OF THE RICH')),
      body: LuxuryBackground(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: leaderboard.isEmpty
                  ? const _EmptyState()
                  : Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                          child: Text(
                            'The bravest pay the most.\nAre they also the smartest? 🤔',
                            textAlign: TextAlign.center,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(fontStyle: FontStyle.italic),
                          ),
                        ),
                        const Divider(color: AppTheme.divider),
                        if (leaderboard.length >= 2)
                          _Podium(
                            leaderboard: leaderboard,
                            currentId: currentId,
                          ),
                        Expanded(
                          child: ListView.builder(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            itemCount: leaderboard.length,
                            itemBuilder: (context, i) {
                              final user = leaderboard[i];
                              return _RankTile(
                                rank: i + 1,
                                user: user,
                                isCurrentUser: user.id == currentId,
                              );
                            },
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Podium für die Top 3
// ---------------------------------------------------------------------------
class _Podium extends StatelessWidget {
  final List<UserModel> leaderboard;
  final String? currentId;

  const _Podium({required this.leaderboard, required this.currentId});

  @override
  Widget build(BuildContext context) {
    final first = leaderboard[0];
    final second = leaderboard.length > 1 ? leaderboard[1] : null;
    final third = leaderboard.length > 2 ? leaderboard[2] : null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (second != null)
            Expanded(
              child: _PodiumBlock(
                user: second,
                rank: 2,
                height: 74,
                isCurrentUser: second.id == currentId,
              ),
            )
          else
            const Expanded(child: SizedBox()),
          Expanded(
            child: _PodiumBlock(
              user: first,
              rank: 1,
              height: 104,
              isCurrentUser: first.id == currentId,
            ),
          ),
          if (third != null)
            Expanded(
              child: _PodiumBlock(
                user: third,
                rank: 3,
                height: 58,
                isCurrentUser: third.id == currentId,
              ),
            )
          else
            const Expanded(child: SizedBox()),
        ],
      ),
    );
  }
}

class _PodiumBlock extends StatelessWidget {
  final UserModel user;
  final int rank;
  final double height;
  final bool isCurrentUser;

  const _PodiumBlock({
    required this.user,
    required this.rank,
    required this.height,
    required this.isCurrentUser,
  });

  String get _medal => rank == 1
      ? '🥇'
      : rank == 2
          ? '🥈'
          : '🥉';

  Color get _color => rank == 1
      ? AppTheme.gold
      : rank == 2
          ? AppTheme.silver
          : AppTheme.bronze;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _openPublicProfile(
        context,
        user: user,
        rank: rank,
        isCurrentUser: isCurrentUser,
      ),
      borderRadius: BorderRadius.circular(12),
      child: Column(
        children: [
          UserAvatar(
            emoji: user.avatar,
            imagePath: user.avatarPath,
            size: 34,
          ),
          Text(_medal, style: const TextStyle(fontSize: 20)),
          const SizedBox(height: 2),
          Text(
            user.username,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                color: _color, fontSize: 11, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Container(
            height: height,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  _color.withValues(alpha: 0.30),
                  _color.withValues(alpha: 0.08),
                ],
              ),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(10)),
              border: Border.all(color: _color.withValues(alpha: 0.6)),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      PaymentConfig.format(user.totalSpentMinor),
                      style: TextStyle(
                        color: _color,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Text(
                    'spent',
                    style: TextStyle(
                        color: _color.withValues(alpha: 0.8), fontSize: 9),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Listeneintrag pro Rang
// ---------------------------------------------------------------------------
class _RankTile extends StatelessWidget {
  final int rank;
  final UserModel user;
  final bool isCurrentUser;

  const _RankTile({
    required this.rank,
    required this.user,
    required this.isCurrentUser,
  });

  @override
  Widget build(BuildContext context) {
    final medalColor = rank == 1
        ? AppTheme.gold
        : rank == 2
            ? AppTheme.silver
            : rank == 3
                ? AppTheme.bronze
                : AppTheme.textSecondary;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: isCurrentUser
            ? AppTheme.gold.withValues(alpha: 0.08)
            : AppTheme.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isCurrentUser ? AppTheme.gold : AppTheme.divider,
          width: isCurrentUser ? 1 : 0.5,
        ),
      ),
      child: ListTile(
        onTap: () => _openPublicProfile(
          context,
          user: user,
          rank: rank,
          isCurrentUser: isCurrentUser,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: SizedBox(
          width: 44,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 26,
                child: Text(
                  rank <= 3 ? ['🥇', '🥈', '🥉'][rank - 1] : '$rank',
                  style: TextStyle(
                    fontSize: rank <= 3 ? 20 : 14,
                    color: medalColor,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
        title: Row(
          children: [
            UserAvatar(
              emoji: user.avatar,
              imagePath: user.avatarPath,
              size: 28,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                user.username,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isCurrentUser ? AppTheme.gold : AppTheme.textPrimary,
                  fontWeight:
                      isCurrentUser ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
            if (isCurrentUser) ...[
              const SizedBox(width: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.goldDark.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'YOU',
                  style: TextStyle(
                    color: AppTheme.gold,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ],
          ],
        ),
        subtitle: _RankSubtitle(user: user),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                PaymentConfig.format(user.totalSpentMinor),
                style: const TextStyle(
                  color: AppTheme.gold,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const Text(
              'spent',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 9),
            ),
          ],
        ),
      ),
    );
  }
}

void _openPublicProfile(
  BuildContext context, {
  required UserModel user,
  required int rank,
  required bool isCurrentUser,
}) {
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => PublicProfileScreen(
        user: user,
        leaderboardRank: rank,
        isCurrentUser: isCurrentUser,
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// Leerer Zustand
// ---------------------------------------------------------------------------
/// Untertitel im Ranglisten-Eintrag: Rang-Titel + freigeschaltete Resultate.
class _RankSubtitle extends StatelessWidget {
  final UserModel user;
  const _RankSubtitle({required this.user});

  @override
  Widget build(BuildContext context) {
    final rank = rankForSpent(user.totalSpentMinor);
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        children: [
          Icon(rank.icon, size: 12, color: rank.color),
          const SizedBox(width: 4),
          Text(
            rank.name,
            style: TextStyle(
              color: rank.color,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            '  •  ${user.unlockedResultsCount} results',
            style: const TextStyle(
                color: AppTheme.textSecondary, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('💰', style: TextStyle(fontSize: 60)),
            const SizedBox(height: 16),
            const Text(
              'No rich people here yet',
              style: TextStyle(
                color: AppTheme.gold,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Unlock a few results to appear on the leaderboard.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
