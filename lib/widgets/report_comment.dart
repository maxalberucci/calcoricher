import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import '../theme/app_theme.dart';

const List<String> _reasons = [
  'Spam',
  'Harassment',
  'Hate speech',
  'Inappropriate content',
  'Other',
];

/// Öffnet einen Dialog, in dem ein Grund gewählt wird, und meldet den Kommentar.
/// Zeigt anschließend eine klare Bestätigung per SnackBar.
Future<void> showReportCommentDialog(
  BuildContext context, {
  required String ownerId,
  required String commentId,
}) async {
  final reason = await showDialog<String>(
    context: context,
    builder: (_) => const _ReportDialog(),
  );
  if (reason == null) return;
  if (!context.mounted) return;

  final messenger = ScaffoldMessenger.of(context);
  final added = await context.read<UserProvider>().reportProfileComment(
        targetUserId: ownerId,
        commentId: commentId,
        reason: reason,
      );
  messenger.showSnackBar(
    SnackBar(
      content: Text(added ? 'Comment reported ✓' : 'You already reported this.'),
      backgroundColor: added ? AppTheme.goldDark : AppTheme.cardHigh,
      duration: const Duration(seconds: 2),
    ),
  );
}

class _ReportDialog extends StatefulWidget {
  const _ReportDialog();

  @override
  State<_ReportDialog> createState() => _ReportDialogState();
}

class _ReportDialogState extends State<_ReportDialog> {
  String _selected = _reasons.first;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.cardHigh,
      title: const Row(
        children: [
          Icon(Icons.flag_outlined, color: AppTheme.gold, size: 20),
          SizedBox(width: 8),
          Text('Report comment', style: TextStyle(color: AppTheme.gold)),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final reason in _reasons)
            InkWell(
              onTap: () => setState(() => _selected = reason),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                child: Row(
                  children: [
                    Icon(
                      _selected == reason
                          ? Icons.radio_button_checked
                          : Icons.radio_button_unchecked,
                      size: 20,
                      color: _selected == reason
                          ? AppTheme.gold
                          : AppTheme.textSecondary,
                    ),
                    const SizedBox(width: 10),
                    Text(reason,
                        style: const TextStyle(color: AppTheme.textPrimary)),
                  ],
                ),
              ),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(_selected),
          child: const Text('Report',
              style: TextStyle(color: Color(0xFFE05A5A))),
        ),
      ],
    );
  }
}
