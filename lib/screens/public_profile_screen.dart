import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../gamification/achievements.dart';
import '../gamification/ranks.dart';
import '../models/profile_comment.dart';
import '../models/user_model.dart';
import '../payments/payment_config.dart';
import '../providers/user_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/luxury_background.dart';
import '../widgets/profile_showcase.dart';
import '../widgets/user_avatar.dart';

String _formatTimestamp(int timestamp) {
  final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
  String two(int value) => value.toString().padLeft(2, '0');
  return '${two(date.day)}.${two(date.month)}.${date.year} '
      '${two(date.hour)}:${two(date.minute)}';
}

class PublicProfileScreen extends StatelessWidget {
  final UserModel user;
  final int leaderboardRank;

  const PublicProfileScreen({
    super.key,
    required this.user,
    required this.leaderboardRank,
  });

  @override
  Widget build(BuildContext context) {
    final userProvider = context.watch<UserProvider>();
    final visibleUser = userProvider.userById(user.id) ?? user;
    final currentUser = userProvider.currentUser;
    final ownerIsViewing = currentUser?.id == visibleUser.id;
    final rank = rankForSpent(visibleUser.totalSpentMinor);
    final currentLeaderboardRank =
        userProvider.leaderboardRankOf(visibleUser.id);

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(ownerIsViewing ? 'YOUR PUBLIC PROFILE' : 'PROFILE'),
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
                    ProfileShowcase(user: visibleUser, showEmptyHint: false),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: _ProfileStatCard(
                            icon: Icons.leaderboard,
                            label: 'Leaderboard',
                            value: '#${currentLeaderboardRank == 0 ? leaderboardRank : currentLeaderboardRank}',
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
                            value:
                                PaymentConfig.format(visibleUser.totalSpentMinor),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _ProfileStatCard(
                            icon: Icons.lock_open,
                            label: 'Results',
                            value: '${visibleUser.unlockedResultsCount}',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _ProfileStatCard(
                      icon: Icons.rocket_launch,
                      label: 'Highest unlock',
                      value: PaymentConfig.format(visibleUser.highestUnlockMinor),
                    ),
                    const SizedBox(height: 24),
                    _ProfileCommentsSection(
                      user: visibleUser,
                      currentUser: currentUser,
                      ownerIsViewing: ownerIsViewing,
                    ),
                    const SizedBox(height: 24),
                    _PublicAchievements(user: visibleUser),
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

class _ProfileCommentsSection extends StatelessWidget {
  final UserModel user;
  final UserModel? currentUser;
  final bool ownerIsViewing;

  const _ProfileCommentsSection({
    required this.user,
    required this.currentUser,
    required this.ownerIsViewing,
  });

  @override
  Widget build(BuildContext context) {
    final canComment = currentUser != null && !ownerIsViewing;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'COMMENTS',
              style: TextStyle(
                color: AppTheme.gold,
                fontSize: 11,
                letterSpacing: 2,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Spacer(),
            Text(
              '${user.profileComments.length}',
              style: const TextStyle(
                color: AppTheme.gold,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (canComment) ...[
          _CommentComposer(targetUserId: user.id),
          const SizedBox(height: 14),
        ],
        if (user.profileComments.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.divider),
            ),
            child: Text(
              ownerIsViewing
                  ? 'No comments on your profile yet.'
                  : 'No comments yet.',
              style: const TextStyle(color: AppTheme.textSecondary),
            ),
          )
        else
          Column(
            children: user.profileComments
                .map((comment) => Padding(
                      key: ValueKey(comment.id),
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _ProfileCommentTile(
                        comment: comment,
                        profileOwner: user,
                        ownerIsViewing: ownerIsViewing,
                      ),
                    ))
                .toList(),
          ),
      ],
    );
  }
}

class _CommentComposer extends StatefulWidget {
  final String targetUserId;

  const _CommentComposer({required this.targetUserId});

  @override
  State<_CommentComposer> createState() => _CommentComposerState();
}

class _CommentComposerState extends State<_CommentComposer> {
  final _controller = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    final messenger = ScaffoldMessenger.of(context);
    setState(() => _saving = true);
    await context.read<UserProvider>().addProfileComment(
          targetUserId: widget.targetUserId,
          text: text,
        );
    if (!mounted) return;
    _controller.clear();
    setState(() => _saving = false);
    FocusScope.of(context).unfocus();
    messenger.showSnackBar(
      const SnackBar(
        content: Text('Comment posted ✓'),
        backgroundColor: AppTheme.goldDark,
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.goldDark, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _controller,
            minLines: 2,
            maxLines: 4,
            maxLength: 180,
            style: const TextStyle(color: AppTheme.textPrimary),
            decoration: const InputDecoration(
              hintText: 'Write a public comment',
              labelText: 'Comment',
              alignLabelWithHint: true,
              prefixIcon: Icon(Icons.chat_bubble_outline, color: AppTheme.gold),
              counterStyle: TextStyle(color: AppTheme.textSecondary),
            ),
          ),
          const SizedBox(height: 10),
          ElevatedButton.icon(
            onPressed: _saving ? null : _submit,
            icon: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.black,
                    ),
                  )
                : const Icon(Icons.send),
            label: const Text('POST COMMENT'),
          ),
        ],
      ),
    );
  }
}

class _ProfileCommentTile extends StatelessWidget {
  final ProfileComment comment;
  final UserModel profileOwner;
  final bool ownerIsViewing;

  const _ProfileCommentTile({
    required this.comment,
    required this.profileOwner,
    required this.ownerIsViewing,
  });

  @override
  Widget build(BuildContext context) {
    final hasReply =
        comment.ownerReply != null && comment.ownerReply!.trim().isNotEmpty;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.divider, width: 0.5),
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
                      _formatTimestamp(comment.timestamp),
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
          const SizedBox(height: 10),
          Text(
            comment.text,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 14,
              height: 1.35,
            ),
          ),
          if (hasReply) ...[
            const SizedBox(height: 12),
            _OwnerReplyBox(comment: comment, profileOwner: profileOwner),
          ],
          if (ownerIsViewing) ...[
            const SizedBox(height: 12),
            _OwnerReplyComposer(
              targetUserId: profileOwner.id,
              commentId: comment.id,
              initialText: comment.ownerReply ?? '',
              hasExistingReply: hasReply,
            ),
          ],
        ],
      ),
    );
  }
}

class _OwnerReplyBox extends StatelessWidget {
  final ProfileComment comment;
  final UserModel profileOwner;

  const _OwnerReplyBox({
    required this.comment,
    required this.profileOwner,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.gold.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.goldDark.withValues(alpha: 0.55)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          UserAvatar(
            name: profileOwner.username,
            imagePath: profileOwner.avatarPath,
            size: 28,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${profileOwner.username} replied',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppTheme.gold,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (comment.ownerReplyTimestamp != null)
                  Text(
                    _formatTimestamp(comment.ownerReplyTimestamp!),
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 10,
                    ),
                  ),
                const SizedBox(height: 6),
                Text(
                  comment.ownerReply ?? '',
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 13,
                    height: 1.35,
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

class _OwnerReplyComposer extends StatefulWidget {
  final String targetUserId;
  final String commentId;
  final String initialText;
  final bool hasExistingReply;

  const _OwnerReplyComposer({
    required this.targetUserId,
    required this.commentId,
    required this.initialText,
    required this.hasExistingReply,
  });

  @override
  State<_OwnerReplyComposer> createState() => _OwnerReplyComposerState();
}

class _OwnerReplyComposerState extends State<_OwnerReplyComposer> {
  late final TextEditingController _controller;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialText);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final reply = _controller.text.trim();
    if (reply.isEmpty) return;

    final messenger = ScaffoldMessenger.of(context);
    setState(() => _saving = true);
    await context.read<UserProvider>().replyToProfileComment(
          targetUserId: widget.targetUserId,
          commentId: widget.commentId,
          reply: reply,
        );
    if (!mounted) return;
    setState(() => _saving = false);
    FocusScope.of(context).unfocus();
    messenger.showSnackBar(
      const SnackBar(
        content: Text('Reply sent ✓'),
        backgroundColor: AppTheme.goldDark,
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _controller,
          minLines: 1,
          maxLines: 3,
          maxLength: 160,
          style: const TextStyle(color: AppTheme.textPrimary),
          decoration: InputDecoration(
            hintText: widget.hasExistingReply ? 'Edit reply' : 'Reply as owner',
            labelText: widget.hasExistingReply ? 'Owner reply' : 'Reply',
            prefixIcon: const Icon(Icons.reply, color: AppTheme.gold),
            counterStyle: const TextStyle(color: AppTheme.textSecondary),
          ),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _saving ? null : _submit,
          icon: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppTheme.gold,
                  ),
                )
              : const Icon(Icons.reply),
          label: Text(widget.hasExistingReply ? 'UPDATE REPLY' : 'REPLY'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppTheme.gold,
            side: const BorderSide(color: AppTheme.goldDark),
          ),
        ),
      ],
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
