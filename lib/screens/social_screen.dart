import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../payments/payment_config.dart';
import '../providers/user_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/gold_text.dart';
import '../widgets/luxury_background.dart';

class SocialScreen extends StatelessWidget {
  const SocialScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<UserProvider>();
    final daily = provider.dailyRichQuestion;
    final feed = provider.publicFeed;

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: AppBar(title: const Text('SOCIAL RICHNESS')),
      body: LuxuryBackground(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _Section(
                      title: 'DAILY RICH QUESTION',
                      icon: Icons.today,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            daily.expression,
                            style: const TextStyle(
                              color: AppTheme.gold,
                              fontSize: 30,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Everyone gets the same pointless flex on ${daily.date}.',
                            style:
                                const TextStyle(color: AppTheme.textSecondary),
                          ),
                          _MiniLeaderboard(
                            users: provider.dailyLeaderboard(daily.date),
                            emptyText: 'No daily reveals yet.',
                          ),
                        ],
                      ),
                    ),
                    _Section(
                      title: 'RECENTLY UNLOCKED',
                      icon: Icons.bolt,
                      child: feed.isEmpty
                          ? const Text(
                              'No public flexes yet. Unlock a result to make the room feel alive.',
                              style: TextStyle(color: AppTheme.textSecondary),
                            )
                          : Column(
                              children: feed.take(6).map((item) {
                                return _FeedRow(
                                  by: item.by,
                                  expression: item.expression,
                                  amount:
                                      PaymentConfig.format(item.amountMinor),
                                  shareText: item.shareText,
                                );
                              }).toList(),
                            ),
                    ),
                    _Section(
                      title: 'PRIVATE ROOMS',
                      icon: Icons.meeting_room,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Create a friend-room and compete on spending, highest unlocks, and ridiculous math.',
                            style: TextStyle(color: AppTheme.textSecondary),
                          ),
                          const SizedBox(height: 10),
                          if (provider.rooms.isEmpty)
                            const Text(
                              'No rooms yet.',
                              style: TextStyle(color: AppTheme.textSecondary),
                            )
                          else
                            for (final room in provider.rooms.take(3))
                              _RoomRow(room: room, provider: provider),
                          const SizedBox(height: 10),
                          OutlinedButton.icon(
                            onPressed: provider.currentUser == null
                                ? null
                                : () => provider.createRoom(
                                      title: 'Private Rich Room',
                                    ),
                            icon: const Icon(Icons.add),
                            label: const Text('CREATE ROOM'),
                          ),
                        ],
                      ),
                    ),
                    _Section(
                      title: 'CREATOR MODE',
                      icon: Icons.live_tv,
                      child: _ContextActivator(
                        activeLabel: provider.activeChallengeSlug,
                        emptyLabel: 'No active creator challenge.',
                        buttonLabel: 'ACTIVATE STREAMER-NIGHT',
                        onPressed: provider.currentUser == null
                            ? null
                            : () =>
                                provider.activateChallenge('streamer-night'),
                      ),
                    ),
                    _Section(
                      title: 'CHARITY MODE',
                      icon: Icons.volunteer_activism,
                      child: _ContextActivator(
                        activeLabel: provider.activeCharityCampaignId,
                        emptyLabel: 'No charity campaign selected.',
                        buttonLabel: 'BURN MONEY FOR MATH-RELIEF',
                        onPressed: provider.currentUser == null
                            ? null
                            : () =>
                                provider.activateCharityCampaign('math-relief'),
                      ),
                    ),
                    const _Section(
                      title: 'SPENDING GUARDRAILS',
                      icon: Icons.health_and_safety,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            PaymentConfig.satireDisclosure,
                            style: TextStyle(color: AppTheme.textSecondary),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Daily max: ${PaymentConfig.currencySymbol} 100.00',
                            style: TextStyle(
                              color: AppTheme.gold,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Refund/help: ${PaymentConfig.refundUrl}',
                            style: TextStyle(color: AppTheme.textSecondary),
                          ),
                        ],
                      ),
                    ),
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

class _Section extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;

  const _Section({
    required this.title,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppTheme.gold, size: 20),
              const SizedBox(width: 8),
              GoldText(
                title,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.4,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _FeedRow extends StatelessWidget {
  final String by;
  final String expression;
  final String amount;
  final String shareText;

  const _FeedRow({
    required this.by,
    required this.expression,
    required this.amount,
    required this.shareText,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          const Icon(Icons.receipt_long, color: AppTheme.gold, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '$by unlocked $expression for $amount',
              style: const TextStyle(color: AppTheme.textPrimary),
            ),
          ),
          Tooltip(
            message: shareText,
            child: const Icon(Icons.ios_share,
                color: AppTheme.textSecondary, size: 18),
          ),
        ],
      ),
    );
  }
}

class _RoomRow extends StatelessWidget {
  final RichRoom room;
  final UserProvider provider;

  const _RoomRow({required this.room, required this.provider});

  @override
  Widget build(BuildContext context) {
    final leaders = provider.roomCompetition(room.code);
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${room.title} · ${room.code}',
            style: const TextStyle(color: AppTheme.textPrimary),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 10,
            runSpacing: 4,
            children: [
              _MetricLabel(label: 'Spend', value: _name(leaders.spent)),
              _MetricLabel(
                label: 'Highest unlock',
                value: _name(leaders.highestUnlock),
              ),
              _MetricLabel(
                label: 'Most ridiculous',
                value: _name(leaders.ridiculous),
              ),
              _MetricLabel(
                label: 'Fastest reveal',
                value: _name(leaders.fastest),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _name(List<CompetitionEntry> entries) =>
      entries.isEmpty ? 'no reveals' : entries.first.username;
}

class _MetricLabel extends StatelessWidget {
  final String label;
  final String value;

  const _MetricLabel({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Text(
      '$label: $value',
      style: const TextStyle(color: AppTheme.gold, fontSize: 12),
    );
  }
}

class _MiniLeaderboard extends StatelessWidget {
  final List<dynamic> users;
  final String emptyText;

  const _MiniLeaderboard({required this.users, required this.emptyText});

  @override
  Widget build(BuildContext context) {
    if (users.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Text(
          emptyText,
          style: const TextStyle(color: AppTheme.textSecondary),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Text(
        'Leader: ${users.first.username}',
        style: const TextStyle(color: AppTheme.gold),
      ),
    );
  }
}

class _ContextActivator extends StatelessWidget {
  final String? activeLabel;
  final String emptyLabel;
  final String buttonLabel;
  final VoidCallback? onPressed;

  const _ContextActivator({
    required this.activeLabel,
    required this.emptyLabel,
    required this.buttonLabel,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          activeLabel == null ? emptyLabel : 'Active: $activeLabel',
          style: const TextStyle(color: AppTheme.textSecondary),
        ),
        const SizedBox(height: 10),
        OutlinedButton(
          onPressed: onPressed,
          child: Text(buttonLabel),
        ),
      ],
    );
  }
}
