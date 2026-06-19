import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/admin_config.dart';
import '../gamification/ranks.dart';
import '../models/profile_comment.dart';
import '../models/user_model.dart';
import '../payments/payment_config.dart';
import '../providers/user_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/luxury_background.dart';
import '../widgets/user_avatar.dart';
import 'login_screen.dart';

const _danger = Color(0xFFE05A5A);

String _formatTimestamp(int timestamp) {
  if (timestamp <= 0) return 'Unknown';
  final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
  String two(int value) => value.toString().padLeft(2, '0');
  return '${two(date.day)}.${two(date.month)}.${date.year} '
      '${two(date.hour)}:${two(date.minute)}';
}

int _commentReportCount(UserModel user) =>
    user.profileComments.fold(0, (sum, c) => sum + c.reports.length);

int _createdSortValue(UserModel user) {
  final raw = user.id.split('_').first;
  return int.tryParse(raw) ?? 0;
}

/// Reines Admin-Dashboard: Übersicht, Nutzerverwaltung und Report-Tool.
class AdminScreen extends StatelessWidget {
  const AdminScreen({super.key});

  Future<void> _logout(BuildContext context) async {
    await context.read<UserProvider>().logout();
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<UserProvider>();

    if (!provider.isAdmin) {
      return const Scaffold(
        backgroundColor: AppTheme.background,
        body: Center(
          child: Text(
            'Access denied',
            style: TextStyle(color: AppTheme.textSecondary),
          ),
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
          actions: [
            IconButton(
              tooltip: 'Sign out',
              icon: const Icon(Icons.logout, color: AppTheme.gold),
              onPressed: () => _logout(context),
            ),
          ],
          bottom: TabBar(
            indicatorColor: AppTheme.gold,
            labelColor: AppTheme.gold,
            unselectedLabelColor: AppTheme.textSecondary,
            labelStyle: AppTheme.sans(
              const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
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
                constraints: const BoxConstraints(maxWidth: 760),
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

class _OverviewTab extends StatelessWidget {
  const _OverviewTab();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<UserProvider>();
    final stats = provider.adminStats;
    final users = provider.allUsers;
    final activeUsers =
        users.where((u) => !u.isBanned && !AdminConfig.isAdmin(u.email)).length;
    final topSpender = users.isEmpty ? null : users.first;
    final flaggedUsers = users.where((u) => _commentReportCount(u) > 0).toList()
      ..sort(
          (a, b) => _commentReportCount(b).compareTo(_commentReportCount(a)));
    final newestUsers = [...users]
      ..sort((a, b) => _createdSortValue(b).compareTo(_createdSortValue(a)));
    final averageSpend =
        stats.users == 0 ? 0 : stats.totalSpentMinor ~/ stats.users;
    final tiles = [
      _StatTile(icon: Icons.group, label: 'Users', value: '${stats.users}'),
      _StatTile(
        icon: Icons.person_add_alt,
        label: 'Active users',
        value: '$activeUsers',
      ),
      _StatTile(
        icon: Icons.block,
        label: 'Banned',
        value: '${stats.banned}',
        color: _danger,
      ),
      _StatTile(
        icon: Icons.chat_bubble_outline,
        label: 'Comments',
        value: '${stats.comments}',
      ),
      _StatTile(
        icon: Icons.flag,
        label: 'Open reports',
        value: '${stats.reports}',
        color: stats.reports > 0 ? _danger : AppTheme.gold,
      ),
      _StatTile(
        icon: Icons.lock_open,
        label: 'Results unlocked',
        value: '${stats.results}',
      ),
      _StatTile(
        icon: Icons.payments,
        label: 'Total revenue',
        value: PaymentConfig.format(stats.totalSpentMinor),
      ),
      _StatTile(
        icon: Icons.trending_up,
        label: 'Average spend',
        value: PaymentConfig.format(averageSpend),
      ),
      _StatTile(
        icon: Icons.diamond,
        label: 'Top spender',
        value: topSpender == null
            ? PaymentConfig.format(0)
            : PaymentConfig.format(topSpender.totalSpentMinor),
      ),
    ];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.65,
          children: tiles,
        ),
        const SizedBox(height: 18),
        const _SectionTitle('TOP SPENDERS'),
        _OverviewUserList(
          users: users.take(5).toList(),
          emptyText: 'No users yet.',
          metricFor: (user) => PaymentConfig.format(user.totalSpentMinor),
        ),
        const SizedBox(height: 16),
        const _SectionTitle('FLAGGED USERS'),
        _OverviewUserList(
          users: flaggedUsers.take(5).toList(),
          emptyText: 'No open reports.',
          metricFor: (user) => '${_commentReportCount(user)} reports',
          metricColor: _danger,
        ),
        const SizedBox(height: 16),
        const _SectionTitle('NEWEST USERS'),
        _OverviewUserList(
          users: newestUsers.take(5).toList(),
          emptyText: 'No users yet.',
          metricFor: (user) =>
              _formatTimestamp(_createdSortValue(user) ~/ 1000),
        ),
      ],
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
        borderRadius: BorderRadius.circular(10),
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
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _OverviewUserList extends StatelessWidget {
  final List<UserModel> users;
  final String emptyText;
  final String Function(UserModel) metricFor;
  final Color metricColor;

  const _OverviewUserList({
    required this.users,
    required this.emptyText,
    required this.metricFor,
    this.metricColor = AppTheme.gold,
  });

  @override
  Widget build(BuildContext context) {
    if (users.isEmpty) {
      return _Panel(
        child: Text(
          emptyText,
          style: const TextStyle(color: AppTheme.textSecondary),
        ),
      );
    }

    return _Panel(
      child: Column(
        children: [
          for (var i = 0; i < users.length; i++) ...[
            _OverviewUserRow(
              user: users[i],
              metric: metricFor(users[i]),
              metricColor: metricColor,
            ),
            if (i != users.length - 1)
              const Divider(color: AppTheme.divider, height: 16),
          ],
        ],
      ),
    );
  }
}

class _OverviewUserRow extends StatelessWidget {
  final UserModel user;
  final String metric;
  final Color metricColor;

  const _OverviewUserRow({
    required this.user,
    required this.metric,
    required this.metricColor,
  });

  @override
  Widget build(BuildContext context) {
    final isAdmin = AdminConfig.isAdmin(user.email);

    return InkWell(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => _UserDetailScreen(userId: user.id)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            UserAvatar(
                name: user.username, imagePath: user.avatarPath, size: 32),
            const SizedBox(width: 10),
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
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (isAdmin) const _Chip('ADMIN', AppTheme.gold),
                      if (user.isBanned) const _Chip('BANNED', _danger),
                    ],
                  ),
                  Text(
                    user.email,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Text(
              metric,
              style: TextStyle(
                color: metricColor,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _UserFilter { all, active, banned, admins, reported }

enum _UserSort { spent, results, comments, reports, newest, name }

class _UsersTab extends StatefulWidget {
  const _UsersTab();

  @override
  State<_UsersTab> createState() => _UsersTabState();
}

class _UsersTabState extends State<_UsersTab> {
  final _search = TextEditingController();
  _UserFilter _filter = _UserFilter.all;
  _UserSort _sort = _UserSort.spent;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<UserModel> _visibleUsers(List<UserModel> users) {
    final query = _search.text.trim().toLowerCase();
    final filtered = users.where((user) {
      final isAdmin = AdminConfig.isAdmin(user.email);
      final matchesFilter = switch (_filter) {
        _UserFilter.all => true,
        _UserFilter.active => !user.isBanned && !isAdmin,
        _UserFilter.banned => user.isBanned,
        _UserFilter.admins => isAdmin,
        _UserFilter.reported => _commentReportCount(user) > 0,
      };
      if (!matchesFilter) return false;
      if (query.isEmpty) return true;
      return user.username.toLowerCase().contains(query) ||
          user.email.toLowerCase().contains(query) ||
          user.id.toLowerCase().contains(query);
    }).toList();

    filtered.sort((a, b) {
      final byName =
          a.username.toLowerCase().compareTo(b.username.toLowerCase());
      switch (_sort) {
        case _UserSort.spent:
          final bySpent = b.totalSpentMinor.compareTo(a.totalSpentMinor);
          return bySpent != 0 ? bySpent : byName;
        case _UserSort.results:
          final byResults =
              b.unlockedResultsCount.compareTo(a.unlockedResultsCount);
          return byResults != 0 ? byResults : byName;
        case _UserSort.comments:
          final byComments =
              b.profileComments.length.compareTo(a.profileComments.length);
          return byComments != 0 ? byComments : byName;
        case _UserSort.reports:
          final byReports =
              _commentReportCount(b).compareTo(_commentReportCount(a));
          return byReports != 0 ? byReports : byName;
        case _UserSort.newest:
          final byCreated =
              _createdSortValue(b).compareTo(_createdSortValue(a));
          return byCreated != 0 ? byCreated : byName;
        case _UserSort.name:
          return byName;
      }
    });

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final allUsers = context.watch<UserProvider>().allUsers;
    final users = _visibleUsers(allUsers);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Column(
            children: [
              TextField(
                key: const ValueKey('admin-user-search'),
                controller: _search,
                onChanged: (_) => setState(() {}),
                style: const TextStyle(color: AppTheme.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Search users',
                  prefixIcon: const Icon(Icons.search, color: AppTheme.gold),
                  suffixIcon: _search.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Clear search',
                          icon: const Icon(Icons.close),
                          onPressed: () => setState(_search.clear),
                        ),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<_UserFilter>(
                      initialValue: _filter,
                      decoration: const InputDecoration(
                        labelText: 'Filter',
                        prefixIcon: Icon(Icons.filter_list),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: _UserFilter.all,
                          child: Text('All users'),
                        ),
                        DropdownMenuItem(
                          value: _UserFilter.active,
                          child: Text('Active'),
                        ),
                        DropdownMenuItem(
                          value: _UserFilter.banned,
                          child: Text('Banned'),
                        ),
                        DropdownMenuItem(
                          value: _UserFilter.admins,
                          child: Text('Admins'),
                        ),
                        DropdownMenuItem(
                          value: _UserFilter.reported,
                          child: Text('Reported'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) setState(() => _filter = value);
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: DropdownButtonFormField<_UserSort>(
                      initialValue: _sort,
                      decoration: const InputDecoration(
                        labelText: 'Sort',
                        prefixIcon: Icon(Icons.sort),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: _UserSort.spent,
                          child: Text('Spent'),
                        ),
                        DropdownMenuItem(
                          value: _UserSort.results,
                          child: Text('Results'),
                        ),
                        DropdownMenuItem(
                          value: _UserSort.comments,
                          child: Text('Comments'),
                        ),
                        DropdownMenuItem(
                          value: _UserSort.reports,
                          child: Text('Reports'),
                        ),
                        DropdownMenuItem(
                          value: _UserSort.newest,
                          child: Text('Newest'),
                        ),
                        DropdownMenuItem(
                          value: _UserSort.name,
                          child: Text('Name'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) setState(() => _sort = value);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '${users.length} of ${allUsers.length} users',
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: users.isEmpty
              ? const _EmptyState(
                  icon: Icons.manage_search,
                  title: 'No users found',
                  message: 'Adjust search or filters.',
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  itemCount: users.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) => _UserRow(user: users[i]),
                ),
        ),
      ],
    );
  }
}

class _UserRow extends StatelessWidget {
  final UserModel user;
  const _UserRow({required this.user});

  void _openDetails(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => _UserDetailScreen(userId: user.id)),
    );
  }

  Future<void> _toggleBan(BuildContext context) async {
    final provider = context.read<UserProvider>();
    if (!user.isBanned) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppTheme.cardHigh,
          title:
              const Text('Ban user?', style: TextStyle(color: AppTheme.gold)),
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
              child: const Text('Ban', style: TextStyle(color: _danger)),
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
    final reports = _commentReportCount(user);

    return InkWell(
      key: ValueKey('admin-user-row-${user.email}'),
      borderRadius: BorderRadius.circular(10),
      onTap: () => _openDetails(context),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.card,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: user.isBanned ? _danger : AppTheme.divider,
            width: user.isBanned ? 1 : 0.5,
          ),
        ),
        child: Row(
          children: [
            UserAvatar(
                name: user.username, imagePath: user.avatarPath, size: 42),
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
                      if (user.isBanned) const _Chip('BANNED', _danger),
                    ],
                  ),
                  Text(
                    user.email,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Wrap(
                    spacing: 8,
                    runSpacing: 2,
                    children: [
                      _MetaText('${rank.name} rank', color: rank.color),
                      _MetaText(PaymentConfig.format(user.totalSpentMinor)),
                      _MetaText('${user.unlockedResultsCount} results'),
                      _MetaText('${user.profileComments.length} comments'),
                      if (reports > 0)
                        _MetaText('$reports reports', color: _danger),
                    ],
                  ),
                ],
              ),
            ),
            if (!isAdmin)
              IconButton(
                tooltip: user.isBanned ? 'Unban' : 'Ban',
                icon: Icon(
                  user.isBanned ? Icons.lock_open : Icons.block,
                  color: user.isBanned ? AppTheme.textSecondary : _danger,
                ),
                onPressed: () => _toggleBan(context),
              ),
            const Icon(Icons.chevron_right, color: AppTheme.textSecondary),
          ],
        ),
      ),
    );
  }
}

class _UserDetailScreen extends StatelessWidget {
  final String userId;
  const _UserDetailScreen({required this.userId});

  Future<void> _toggleBan(BuildContext context, UserModel user) async {
    if (AdminConfig.isAdmin(user.email)) return;
    if (!user.isBanned) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppTheme.cardHigh,
          title:
              const Text('Ban user?', style: TextStyle(color: AppTheme.gold)),
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
              child: const Text('Ban', style: TextStyle(color: _danger)),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }
    if (!context.mounted) return;
    await context
        .read<UserProvider>()
        .adminSetBanned(userId: user.id, banned: !user.isBanned);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<UserProvider>();
    final user = provider.userById(userId);

    if (!provider.isAdmin || user == null) {
      return const Scaffold(
        backgroundColor: AppTheme.background,
        body: Center(
          child: Text('User not available',
              style: TextStyle(color: AppTheme.textSecondary)),
        ),
      );
    }

    final rank = rankForSpent(user.totalSpentMinor);
    final isAdmin = AdminConfig.isAdmin(user.email);
    final reports = _commentReportCount(user);

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: AppBar(title: const Text('USER DETAILS')),
      body: LuxuryBackground(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _Panel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            UserAvatar(
                              name: user.username,
                              imagePath: user.avatarPath,
                              size: 58,
                              bordered: true,
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 4,
                                    crossAxisAlignment:
                                        WrapCrossAlignment.center,
                                    children: [
                                      Text(
                                        user.username,
                                        style: const TextStyle(
                                          color: AppTheme.gold,
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      if (isAdmin)
                                        const _Chip('ADMIN', AppTheme.gold),
                                      if (user.isBanned)
                                        const _Chip('BANNED', _danger),
                                    ],
                                  ),
                                  Text(
                                    user.email,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: AppTheme.textSecondary,
                                      fontSize: 12,
                                    ),
                                  ),
                                  Text(
                                    'ID ${user.id}',
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
                          ],
                        ),
                        const SizedBox(height: 14),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _MetricPill(
                              icon: rank.icon,
                              label: rank.name,
                              color: rank.color,
                            ),
                            _MetricPill(
                              icon: Icons.payments,
                              label: PaymentConfig.format(user.totalSpentMinor),
                            ),
                            _MetricPill(
                              icon: Icons.lock_open,
                              label: '${user.unlockedResultsCount} results',
                            ),
                            _MetricPill(
                              icon: Icons.flag,
                              label: '$reports reports',
                              color: reports > 0 ? _danger : AppTheme.gold,
                            ),
                          ],
                        ),
                        if (!isAdmin) ...[
                          const SizedBox(height: 14),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: () => _toggleBan(context, user),
                              icon: Icon(user.isBanned
                                  ? Icons.lock_open
                                  : Icons.block),
                              label: Text(
                                  user.isBanned ? 'UNBAN USER' : 'BAN USER'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor:
                                    user.isBanned ? AppTheme.gold : _danger,
                                side: BorderSide(
                                  color:
                                      user.isBanned ? AppTheme.gold : _danger,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  const _SectionTitle('ACCOUNT STATS'),
                  _StatsGrid(
                    items: [
                      _StatItem('Highest unlock',
                          PaymentConfig.format(user.highestUnlockMinor)),
                      _StatItem('Next price',
                          PaymentConfig.format(user.currentResultPriceMinor)),
                      _StatItem('Name changes', '${user.usernameChanges}'),
                      _StatItem(
                          'Profile comments', '${user.profileComments.length}'),
                      _StatItem(
                          'Unread comments', '${user.unreadCommentCount}'),
                      _StatItem('Unread replies', '${user.unreadReplyCount}'),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const _SectionTitle('PROFILE'),
                  _Panel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _TextLine('Title', user.profileTitle),
                        _TextLine('Bio', user.bio),
                        _TextLine(
                          'Links',
                          user.links.isEmpty ? '' : user.links.join('\n'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const _SectionTitle('RECENT HISTORY'),
                  if (user.history.isEmpty)
                    const _Panel(
                      child: Text(
                        'No unlocked results yet.',
                        style: TextStyle(color: AppTheme.textSecondary),
                      ),
                    )
                  else
                    ...user.history.take(8).map(
                          (entry) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _Panel(
                              child: Row(
                                children: [
                                  const Icon(Icons.calculate_outlined,
                                      color: AppTheme.gold, size: 18),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '${entry.expression} = ${entry.result}',
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: AppTheme.textPrimary,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        Text(
                                          _formatTimestamp(entry.timestamp),
                                          style: const TextStyle(
                                            color: AppTheme.textSecondary,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                  const SizedBox(height: 8),
                  const _SectionTitle('PROFILE COMMENTS'),
                  if (user.profileComments.isEmpty)
                    const _Panel(
                      child: Text(
                        'No profile comments.',
                        style: TextStyle(color: AppTheme.textSecondary),
                      ),
                    )
                  else
                    ...user.profileComments.map(
                      (comment) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _AdminCommentPanel(
                          owner: user,
                          comment: comment,
                        ),
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

class _AdminCommentPanel extends StatelessWidget {
  final UserModel owner;
  final ProfileComment comment;

  const _AdminCommentPanel({required this.owner, required this.comment});

  Future<void> _delete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardHigh,
        title: const Text(
          'Delete comment?',
          style: TextStyle(color: AppTheme.gold),
        ),
        content: const Text(
          'This removes the profile comment permanently.',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: _danger)),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await context.read<UserProvider>().adminDeleteComment(
          targetUserId: owner.id,
          commentId: comment.id,
        );
  }

  Future<void> _dismiss(BuildContext context) async {
    await context.read<UserProvider>().adminDismissReports(
          targetUserId: owner.id,
          commentId: comment.id,
        );
  }

  @override
  Widget build(BuildContext context) {
    return _Panel(
      borderColor: comment.reports.isEmpty ? AppTheme.divider : _danger,
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
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      _formatTimestamp(comment.timestamp),
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              if (comment.reports.isNotEmpty)
                _Chip('${comment.reports.length} REPORTS', _danger),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            comment.text,
            style: const TextStyle(color: AppTheme.textPrimary, height: 1.35),
          ),
          if (comment.ownerReply != null &&
              comment.ownerReply!.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            _InlineNote(
              icon: Icons.reply,
              text: 'Owner reply: ${comment.ownerReply}',
            ),
          ],
          if (comment.reports.isNotEmpty) ...[
            const SizedBox(height: 10),
            for (final report in comment.reports)
              _InlineNote(
                icon: Icons.flag,
                color: _danger,
                text:
                    '${report.reason.isEmpty ? 'No reason' : report.reason} - ${report.reporterName}',
              ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              if (comment.reports.isNotEmpty) ...[
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
              ],
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _delete(context),
                  icon: const Icon(Icons.delete_outline, size: 16),
                  label: const Text('DELETE COMMENT'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _danger,
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

class _ReportsTab extends StatelessWidget {
  const _ReportsTab();

  @override
  Widget build(BuildContext context) {
    final reports = context.watch<UserProvider>().reportedComments;

    if (reports.isEmpty) {
      return const _EmptyState(
        icon: Icons.verified_user_outlined,
        title: 'No reported comments',
        message: 'Everything is clean. Reported comments will appear here.',
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

    return _Panel(
      borderColor: _danger,
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
                      'on ${report.profileOwner.username}\'s profile - '
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
              _Chip('${comment.reports.length} REPORTS', _danger),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(8),
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
                  const Icon(Icons.flag, size: 13, color: _danger),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '${r.reason.isEmpty ? 'No reason' : r.reason} - ${r.reporterName}',
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
                    backgroundColor: _danger,
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
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _MetaText extends StatelessWidget {
  final String text;
  final Color color;

  const _MetaText(this.text, {this.color = AppTheme.textSecondary});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600),
    );
  }
}

class _Panel extends StatelessWidget {
  final Widget child;
  final Color borderColor;

  const _Panel({required this.child, this.borderColor = AppTheme.divider});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor, width: 0.6),
      ),
      child: child,
    );
  }
}

class _MetricPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _MetricPill({
    required this.icon,
    required this.label,
    this.color = AppTheme.gold,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 15),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsGrid extends StatelessWidget {
  final List<_StatItem> items;

  const _StatsGrid({required this.items});

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 2.25,
      children: items
          .map(
            (item) => _Panel(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppTheme.gold,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    item.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}

class _StatItem {
  final String label;
  final String value;

  const _StatItem(this.label, this.value);
}

class _SectionTitle extends StatelessWidget {
  final String text;

  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          color: AppTheme.textSecondary,
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.4,
        ),
      ),
    );
  }
}

class _TextLine extends StatelessWidget {
  final String label;
  final String value;

  const _TextLine(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value.trim().isEmpty ? 'Empty' : value.trim(),
            style: const TextStyle(color: AppTheme.textPrimary, height: 1.35),
          ),
        ],
      ),
    );
  }
}

class _InlineNote extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;

  const _InlineNote({
    required this.icon,
    required this.text,
    this.color = AppTheme.gold,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
          ),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: AppTheme.gold, size: 56),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppTheme.gold,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
