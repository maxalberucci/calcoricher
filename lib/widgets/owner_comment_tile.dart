import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/profile_comment.dart';
import '../providers/user_provider.dart';
import '../theme/app_theme.dart';
import 'user_avatar.dart';

String formatCommentTimestamp(int timestamp) {
  final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
  String two(int value) => value.toString().padLeft(2, '0');
  return '${two(date.day)}.${two(date.month)}.${date.year} '
      '${two(date.hour)}:${two(date.minute)}';
}

/// Ein empfangener Kommentar samt Antwort-Feld für den Profil-Besitzer.
///
/// Das Absenden ruft [UserProvider.replyToProfileComment] auf und bestätigt den
/// Versand klar mit einer SnackBar. Wird im Profil und im Benachrichtigungs-
/// Popup wiederverwendet.
class OwnerCommentTile extends StatefulWidget {
  final ProfileComment comment;
  final String ownerId;
  final bool highlightNew;

  const OwnerCommentTile({
    super.key,
    required this.comment,
    required this.ownerId,
    this.highlightNew = false,
  });

  @override
  State<OwnerCommentTile> createState() => _OwnerCommentTileState();
}

class _OwnerCommentTileState extends State<OwnerCommentTile> {
  late final TextEditingController _controller;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.comment.ownerReply ?? '');
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
          targetUserId: widget.ownerId,
          commentId: widget.comment.id,
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
    final comment = widget.comment;
    final hasReply =
        comment.ownerReply != null && comment.ownerReply!.trim().isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: widget.highlightNew ? AppTheme.gold : AppTheme.divider,
          width: widget.highlightNew ? 1 : 0.5,
        ),
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
                      formatCommentTimestamp(comment.timestamp),
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
              if (widget.highlightNew)
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
            comment.text,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 14,
              height: 1.35,
            ),
          ),
          if (hasReply) ...[
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
                      comment.ownerReply!,
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
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            minLines: 1,
            maxLines: 3,
            maxLength: 160,
            style: const TextStyle(color: AppTheme.textPrimary),
            decoration: InputDecoration(
              hintText: hasReply ? 'Edit reply' : 'Reply',
              labelText: hasReply ? 'Owner reply' : 'Reply',
              prefixIcon: const Icon(Icons.reply, color: AppTheme.gold),
              counterStyle: const TextStyle(color: AppTheme.textSecondary),
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              onPressed: _saving ? null : _submit,
              icon: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.black,
                      ),
                    )
                  : const Icon(Icons.send, size: 18),
              label: Text(hasReply ? 'UPDATE REPLY' : 'SEND REPLY'),
            ),
          ),
        ],
      ),
    );
  }
}
