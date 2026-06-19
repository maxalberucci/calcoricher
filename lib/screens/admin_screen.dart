import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/admin_config.dart';
import '../gamification/ranks.dart';
import '../models/user_model.dart';
import '../payments/payment_config.dart';
import '../providers/user_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/luxury_background.dart';
import '../widgets/user_avatar.dart';

String _formatTimestamp(int timestamp) {
  final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
  String two(int value) => value.toString().padLeft(2, '0');
  return '${two(date.day)}.${two(date.month)}.${date.year} '
      '${two(date.hour)}:${two(date.minute)}';
}

/// Admin-Dashboard: Übersicht, Nutzerverwaltung (bannen) und Report-Tool.
/// Nur für Admin-Konten erreichbar.
class AdminScreen extends StatelessWidget {
  const AdminScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<UserProvider>();

    // Sicherheitsnetz: Nicht-Admins sehen nichts.
    if (!provider.isAdmin) {
      return const Scaffold(
        backgroundColor: AppTheme.background,
        body: Center(
          child: Text('Access denied',
              style: TextStyle(color: AppTheme.textSecondary)),
        ),
      );
    }

    final reportCount = provider.reportedComments.length;

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          title: const Text('ADMIN'),
          bottom: TabBar(
            indicatorColor: AppTheme.gold,
            labelColor: AppTheme.gold,
            unselectedLabelColor: AppTheme.textSecondary,
            labelStyle: AppTheme.sans(
                const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            tabs: [
              const Tab(text: 'OVERVIEW'),
              const Tab(text: 'USERS'),
              Tab(text: reportCount > 0 ? 'REPORTS ($reportCount)' : 'REPORTS'),
            ],
          ),
        ),
        body: LuxuryBackground(
          child: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: const TabBarView(
                  children: [_OverviewTab(), _UsersTab(), _ReportsTab()],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Übersicht
// ---------------------------------------------------------------------------
class _OverviewTab extends StatelessWidget {
  const _OverviewTab();

  @override
  Widget build(BuildContext context) {
    final stats = context.watch<UserProvider>().adminStats;

    final tiles = [
      _StatTile(icon: Icons.group, label: 'Users', value: '${stats.users}'),
      _StatTile(
          icon: Icons.block,
          label: 'Banned',
          value: '${stats.banned}',
          color: const Color(0xFFE05A5A)),
      _StatTile(
          icon: Icons.chat_bubble_outline,
          label: 'Comments',
          value: '${stats.comments}'),
      _StatTile(
          icon: Icons.flag,
          label: 'Open reports',
          value: '${stats.reports}',
          color: stats.reports > 0 ? const Color(0xFFE05A5A) : AppTheme.gold),
      _StatTile(
          icon: Icons.lock_open,
          label: 'Results unlocked',
          value: '${stats.results}'),
      _StatTile(
          icon: Icons.payments,
          label: 'Total revenue',
          value: PaymentConfig.format(stats.totalSpentMinor)),
    ];

    return GridView.count(
      crossAxisCount: 2,
      padding: const EdgeInsets.all(16),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.5,
      children: tiles,
    );
  }
}

class _StatTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatTile({
    required this.icon,
    required this.label,
    required this.value,
    this.color = AppTheme.gold,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.5), width: 0.6),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Nutzerverwaltung
// ---------------------------------------------------------------------------
class _UsersTab extends StatelessWidget {
  const _UsersTab();

  @override
  Widget build(BuildContext context) {
    final users = context.watch<UserProvider>().allUsers;

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: users.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) => _UserRow(user: users[i]),
    );
  }
}

class _UserRow extends StatelessWidget {
  final UserModel user;
  const _UserRow({required this.user});

  Future<void> _toggleBan(BuildContext context) async {
    final provider = context.read<UserProvider>();
    if (!user.isBanned) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppTheme.cardHigh,
          title: const Text('Ban user?', style: TextStyle(color: AppTheme.gold)),
          content: Text(
            '${user.username} will no longer be able to sign in.',
            style: const TextStyle(color: AppTheme.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Ban',
                  style: TextStyle(color: Color(0xFFE05A5A))),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }
    await provider.adminSetBanned(userId: user.id, banned: !user.isBanned);
  }

  @override
  Widget build(BuildContext context) {
    final rank = rankForSpent(user.totalSpentMinor);
    final isAdmin = AdminConfig.isAdmin(user.email);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: user.isBanned ? const Color(0xFFE05A5A) : AppTheme.divider,
          width: user.isBanned ? 1 : 0.5,
        ),
      ),
      child: Row(
        children: [
          UserAvatar(name: user.username, imagePath: user.avatarPath, size: 40),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        user.username,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    if (isAdmin) const _Chip('ADMIN', AppTheme.gold),
                    if (user.isBanned) const _Chip('BANNED', Color(0xFFE05A5A)),
                  ],
                ),
                Text(
                  user.email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: AppTheme.textSecondary, fontSize: 11),
                ),
                const SizedBox(height: 2),
                Text(
                  '${rank.name} · ${PaymentConfig.format(user.totalSpentMinor)} · '
                  '${user.unlockedResultsCount} results',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: rank.color, fontSize: 11),
                ),
              ],
            ),
          ),
          if (!isAdmin)
            IconButton(
              tooltip: user.isBanned ? 'Unban' : 'Ban',
              icon: Icon(
                user.isBanned ? Icons.lock_open : Icons.block,
                color: user.isBanned
                    ? AppTheme.textSecondary
                    : const Color(0xFFE05A5A),
              ),
              onPressed: () => _toggleBan(context),
            ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final Color color;
  const _Chip(this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: 6),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color),
      ),
      child: Text(
        label,
        style: TextStyle(
            color: color, fontSize: 9, fontWeight: FontWeight.bold),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Reports
// ---------------------------------------------------------------------------
class _ReportsTab extends StatelessWidget {
  const _ReportsTab();

  @override
  Widget build(BuildContext context) {
    final reports = context.watch<UserProvider>().reportedComments;

    if (reports.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.verified_user_outlined,
                  color: AppTheme.gold, size: 56),
              const SizedBox(height: 16),
              const Text(
                'No reported comments',
                style: TextStyle(
                  color: AppTheme.gold,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Everything is clean. Reported comments will appear here.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: reports.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, i) => _ReportCard(report: reports[i]),
    );
  }
}

class _ReportCard extends StatelessWidget {
  final ReportedComment report;

  const _ReportCard({required this.report});

  Future<void> _delete(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    await context.read<UserProvider>().adminDeleteComment(
          targetUserId: report.profileOwner.id,
          commentId: report.comment.id,
        );
    messenger.showSnackBar(
      const SnackBar(
        content: Text('Comment deleted'),
        backgroundColor: AppTheme.goldDark,
      ),
    );
  }

  Future<void> _dismiss(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    await context.read<UserProvider>().adminDismissReports(
          targetUserId: report.profileOwner.id,
          commentId: report.comment.id,
        );
    messenger.showSnackBar(
      const SnackBar(content: Text('Reports dismissed')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final comment = report.comment;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE05A5A), width: 0.6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              UserAvatar(
                name: comment.authorName,
                imagePath: comment.authorAvatarPath,
                size: 34,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      comment.authorName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'on ${report.profileOwner.username}\'s profile · '
                      '${_formatTimestamp(comment.timestamp)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFE05A5A).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE05A5A)),
                ),
                child: Text(
                  '${comment.reports.length} ⚑',
                  style: const TextStyle(
                    color: Color(0xFFE05A5A),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              comment.text,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 14,
                height: 1.35,
              ),
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'REPORTS',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 10,
              letterSpacing: 1.5,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          for (final r in comment.reports)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.flag, size: 13, color: Color(0xFFE05A5A)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '${r.reason.isEmpty ? 'No reason' : r.reason} — ${r.reporterName}',
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _dismiss(context),
                  icon: const Icon(Icons.check, size: 16),
                  label: const Text('DISMISS'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.textSecondary,
                    side: const BorderSide(color: AppTheme.divider),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _delete(context),
                  icon: const Icon(Icons.delete_outline, size: 16),
                  label: const Text('DELETE'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE05A5A),
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
