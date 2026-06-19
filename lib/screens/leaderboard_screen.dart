import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/user_model.dart';
import '../payments/payment_config.dart';
import '../gamification/ranks.dart';
import '../providers/user_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/gold_text.dart';
import '../widgets/luxury_background.dart';
import '../widgets/user_avatar.dart';
import 'public_profile_screen.dart';

/// Liefert den für das Sortierkriterium relevanten Anzeigewert eines Nutzers.
String _metricValue(UserModel user, LeaderboardSort sort) {
  switch (sort) {
    case LeaderboardSort.spent:
      return PaymentConfig.format(user.totalSpentMinor);
    case LeaderboardSort.results:
      return '${user.unlockedResultsCount}';
    case LeaderboardSort.highestUnlock:
      return PaymentConfig.format(user.highestUnlockMinor);
  }
}

String _metricLabel(LeaderboardSort sort) {
  switch (sort) {
    case LeaderboardSort.spent:
      return 'spent';
    case LeaderboardSort.results:
      return 'results';
    case LeaderboardSort.highestUnlock:
      return 'top unlock';
  }
}

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  LeaderboardSort _sort = LeaderboardSort.spent;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<UserProvider>();
    final leaderboard = provider.leaderboardBy(_sort);
    final currentId = provider.currentUser?.id;

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
                        _SortSelector(
                          sort: _sort,
                          onChanged: (s) => setState(() => _sort = s),
                        ),
                        const Divider(color: AppTheme.divider, height: 1),
                        if (leaderboard.length >= 2)
                          _Podium(leaderboard: leaderboard, sort: _sort),
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
                                sort: _sort,
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

/// Auswahl des Sortierkriteriums (Betrag · Resultate · Top-Unlock).
class _SortSelector extends StatelessWidget {
  final LeaderboardSort sort;
  final ValueChanged<LeaderboardSort> onChanged;

  const _SortSelector({required this.sort, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: SegmentedButton<LeaderboardSort>(
        showSelectedIcon: false,
        segments: const [
          ButtonSegment(
            value: LeaderboardSort.spent,
            icon: Icon(Icons.payments, size: 16),
            label: Text('Spent'),
          ),
          ButtonSegment(
            value: LeaderboardSort.results,
            icon: Icon(Icons.lock_open, size: 16),
            label: Text('Results'),
          ),
          ButtonSegment(
            value: LeaderboardSort.highestUnlock,
            icon: Icon(Icons.rocket_launch, size: 16),
            label: Text('Top'),
          ),
        ],
        selected: {sort},
        onSelectionChanged: (set) => onChanged(set.first),
        style: ButtonStyle(
          textStyle: WidgetStatePropertyAll(
            AppTheme.sans(const TextStyle(
                fontSize: 12, fontWeight: FontWeight.w600)),
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? Colors.black
                : AppTheme.textSecondary,
          ),
          backgroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? AppTheme.gold
                : Colors.transparent,
          ),
          side: const WidgetStatePropertyAll(
            BorderSide(color: AppTheme.goldDark),
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
  final LeaderboardSort sort;

  const _Podium({required this.leaderboard, required this.sort});

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
              child: _PodiumBlock(user: second, rank: 2, height: 74, sort: sort),
            )
          else
            const Expanded(child: SizedBox()),
          Expanded(
            child: _PodiumBlock(user: first, rank: 1, height: 104, sort: sort),
          ),
          if (third != null)
            Expanded(
              child: _PodiumBlock(user: third, rank: 3, height: 58, sort: sort),
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
  final LeaderboardSort sort;

  const _PodiumBlock({
    required this.user,
    required this.rank,
    required this.height,
    required this.sort,
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
      ),
      borderRadius: BorderRadius.circular(12),
      child: Column(
        children: [
          UserAvatar(
            name: user.username,
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
                    // Der Spitzenreiter bekommt den poliertem Metall-Look.
                    child: rank == 1
                        ? GoldText(
                            _metricValue(user, sort),
                            glow: true,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                        : Text(
                            _metricValue(user, sort),
                            style: TextStyle(
                              color: _color,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                  Text(
                    _metricLabel(sort),
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
  final LeaderboardSort sort;
  final bool isCurrentUser;

  const _RankTile({
    required this.rank,
    required this.user,
    required this.sort,
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
              name: user.username,
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
                _metricValue(user, sort),
                style: const TextStyle(
                  color: AppTheme.gold,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Text(
              _metricLabel(sort),
              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 9),
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
}) {
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => PublicProfileScreen(
        user: user,
        leaderboardRank: rank,
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
