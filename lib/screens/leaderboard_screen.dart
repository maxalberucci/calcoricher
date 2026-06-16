import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/user_model.dart';
import '../providers/user_provider.dart';
import '../theme/app_theme.dart';

class LeaderboardScreen extends StatelessWidget {
  const LeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final leaderboard = context.watch<UserProvider>().leaderboard;
    final currentName = context.watch<UserProvider>().currentUser?.name;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(title: const Text('RANGLISTE DER REICHEN')),
      body: leaderboard.isEmpty
          ? _EmptyState()
          : Column(
              children: [
                // Header quote
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Text(
                    'Die Mutigsten zahlen am meisten.\nSind es auch die Klügsten? 🤔',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontStyle: FontStyle.italic,
                        ),
                  ),
                ),
                const Divider(color: AppTheme.divider),

                // Podium (top 3) if enough users
                if (leaderboard.length >= 2) _Podium(leaderboard: leaderboard),

                // Full list
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    itemCount: leaderboard.length,
                    itemBuilder: (context, i) {
                      final user = leaderboard[i];
                      final isMe = user.name == currentName;
                      return _RankTile(
                        rank: i + 1,
                        user: user,
                        isCurrentUser: isMe,
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}

// ---------------------------------------------------------------------------
// Podium for top 3
// ---------------------------------------------------------------------------
class _Podium extends StatelessWidget {
  final List<UserModel> leaderboard;

  const _Podium({required this.leaderboard});

  @override
  Widget build(BuildContext context) {
    // Arrange: 2nd (left), 1st (center, taller), 3rd (right)
    final first = leaderboard[0];
    final second = leaderboard.length > 1 ? leaderboard[1] : null;
    final third = leaderboard.length > 2 ? leaderboard[2] : null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (second != null) Expanded(child: _PodiumBlock(user: second, rank: 2, height: 70)),
          Expanded(child: _PodiumBlock(user: first, rank: 1, height: 100)),
          if (third != null)
            Expanded(child: _PodiumBlock(user: third, rank: 3, height: 55))
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

  const _PodiumBlock({required this.user, required this.rank, required this.height});

  String get _medal => rank == 1 ? '🥇' : rank == 2 ? '🥈' : '🥉';
  Color get _color => rank == 1 ? AppTheme.gold : rank == 2 ? const Color(0xFFC0C0C0) : const Color(0xFFCD7F32);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(_medal, style: const TextStyle(fontSize: 24)),
        const SizedBox(height: 4),
        Text(
          user.name.length > 8 ? '${user.name.substring(0, 7)}…' : user.name,
          style: TextStyle(color: _color, fontSize: 11, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Container(
          height: height,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: _color.withValues(alpha: 0.15),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
            border: Border.all(color: _color.withValues(alpha: 0.5)),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${user.spentCoins}',
                  style: TextStyle(
                    color: _color,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Coins',
                  style: TextStyle(color: _color.withValues(alpha: 0.7), fontSize: 9),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// List tile for each ranked user
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
    final borderColor = isCurrentUser ? AppTheme.gold : AppTheme.divider;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: isCurrentUser
            ? AppTheme.gold.withValues(alpha: 0.08)
            : AppTheme.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: isCurrentUser ? 1 : 0.5),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: SizedBox(
          width: 40,
          child: Center(
            child: Text(
              rank <= 3 ? ['🥇', '🥈', '🥉'][rank - 1] : '#$rank',
              style: TextStyle(
                fontSize: rank <= 3 ? 22 : 14,
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        title: Row(
          children: [
            Text(
              user.name,
              style: TextStyle(
                color: isCurrentUser ? AppTheme.gold : AppTheme.textPrimary,
                fontWeight: isCurrentUser ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            if (isCurrentUser) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.goldDark.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'DU',
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
        subtitle: Text(
          '${user.resultsShown} Resultate angezeigt  •  ${user.coins} Coins übrig',
          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${user.spentCoins}',
              style: const TextStyle(
                color: AppTheme.gold,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Text(
              'ausgegeben',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 9),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Empty state
// ---------------------------------------------------------------------------
class _EmptyState extends StatelessWidget {
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
              'Noch keine Reichen hier',
              style: TextStyle(
                color: AppTheme.gold,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Zeige ein paar Resultate an, um auf der Rangliste zu erscheinen.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
