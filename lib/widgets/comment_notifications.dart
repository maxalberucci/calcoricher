import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/profile_comment.dart';
import '../providers/user_provider.dart';
import '../theme/app_theme.dart';
import 'owner_comment_tile.dart';
import 'user_avatar.dart';

/// Zeigt ein Benachrichtigungs-Popup mit neuen Kommentaren auf dem eigenen
/// Profil (mit Antwort-Möglichkeit) und neuen Antworten auf eigene Kommentare.
///
/// [newComments] und [newReplies] heben die zuletzt eingegangenen Einträge
/// hervor und steuern die Abschnitts-Überschriften.
Future<void> showCommentNotifications(
  BuildContext context, {
  required String ownerId,
  int newComments = 0,
  int newReplies = 0,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppTheme.cardHigh,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _CommentNotificationsSheet(
      ownerId: ownerId,
      newComments: newComments,
      newReplies: newReplies,
    ),
  );
}

class _CommentNotificationsSheet extends StatelessWidget {
  final String ownerId;
  final int newComments;
  final int newReplies;

  const _CommentNotificationsSheet({
    required this.ownerId,
    required this.newComments,
    required this.newReplies,
  });

  @override
  Widget build(BuildContext context) {
    // Live an den Provider gebunden, damit Antworten sofort sichtbar sind.
    final provider = context.watch<UserProvider>();
    final owner = provider.userById(ownerId);
    final comments = owner?.profileComments ?? const <ProfileComment>[];
    final replies = provider.repliesToMyComments;
    final mediaQuery = MediaQuery.of(context);

    return Padding(
      padding: EdgeInsets.only(bottom: mediaQuery.viewInsets.bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: mediaQuery.size.height * 0.85),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                children: [
                  const Icon(Icons.notifications_active, color: AppTheme.gold),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Notifications',
                      style: TextStyle(
                        color: AppTheme.gold,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: AppTheme.textSecondary),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                children: [
                  if (replies.isNotEmpty) ...[
                    _SectionHeader(
                      label: 'REPLIES TO YOUR COMMENTS',
                      count: replies.length,
                    ),
                    const SizedBox(height: 12),
                    for (var i = 0; i < replies.length; i++) ...[
                      _ReplyNotificationCard(
                        notification: replies[i],
                        isNew: i < newReplies,
                      ),
                      const SizedBox(height: 12),
                    ],
                    const SizedBox(height: 12),
                  ],
                  _SectionHeader(
                    label: 'COMMENTS ON YOUR PROFILE',
                    count: comments.length,
                  ),
                  const SizedBox(height: 12),
                  if (comments.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.card,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppTheme.divider),
                      ),
                      child: const Text(
                        'No comments on your profile yet.',
                        style: TextStyle(color: AppTheme.textSecondary),
                      ),
                    )
                  else
                    for (var i = 0; i < comments.length; i++) ...[
                      OwnerCommentTile(
                        comment: comments[i],
                        ownerId: ownerId,
                        highlightNew: i < newComments,
                      ),
                      const SizedBox(height: 12),
                    ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  final int count;

  const _SectionHeader({required this.label, required this.count});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppTheme.gold,
            fontSize: 11,
            letterSpacing: 2,
            fontWeight: FontWeight.bold,
          ),
        ),
        const Spacer(),
        Text(
          '$count',
          style: const TextStyle(
            color: AppTheme.gold,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

/// Karte für eine Antwort des Profil-Besitzers auf einen eigenen Kommentar.
class _ReplyNotificationCard extends StatelessWidget {
  final ReplyNotification notification;
  final bool isNew;

  const _ReplyNotificationCard({required this.notification, required this.isNew});

  @override
  Widget build(BuildContext context) {
    final owner = notification.profileOwner;
    final comment = notification.comment;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isNew ? AppTheme.gold : AppTheme.divider,
          width: isNew ? 1 : 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              UserAvatar(
                name: owner.username,
                imagePath: owner.avatarPath,
                size: 34,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 13,
                    ),
                    children: [
                      TextSpan(
                        text: owner.username,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const TextSpan(
                        text: ' replied to your comment',
                        style: TextStyle(color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                ),
              ),
              if (isNew)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.gold.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.gold),
                  ),
                  child: const Text(
                    'NEW',
                    style: TextStyle(
                      color: AppTheme.gold,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '“${comment.text}”',
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 13,
              fontStyle: FontStyle.italic,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.gold.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border:
                  Border.all(color: AppTheme.goldDark.withValues(alpha: 0.55)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.subdirectory_arrow_right,
                    color: AppTheme.gold, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    comment.ownerReply ?? '',
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 13,
                      height: 1.35,
                    ),
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
