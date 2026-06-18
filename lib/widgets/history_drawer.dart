import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/history_entry.dart';
import '../providers/user_provider.dart';
import '../theme/app_theme.dart';

/// Von rechts ausklappbarer Verlauf der freigeschalteten Rechnungen.
/// Beim Antippen eines Eintrags wird dessen Resultat über [onPick] geliefert,
/// damit der Rechner damit weiterrechnen kann.
class HistoryDrawer extends StatelessWidget {
  final ValueChanged<String> onPick;

  const HistoryDrawer({super.key, required this.onPick});

  @override
  Widget build(BuildContext context) {
    final userProv = context.watch<UserProvider>();
    final history = userProv.currentUser?.history ?? const <HistoryEntry>[];

    return Drawer(
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(left: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 8, 8),
              child: Row(
                children: [
                  const Icon(Icons.history, color: AppTheme.gold, size: 20),
                  const SizedBox(width: 8),
                  const Text(
                    'VERLAUF',
                    style: TextStyle(
                      color: AppTheme.gold,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                    ),
                  ),
                  const Spacer(),
                  if (history.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.delete_outline,
                          color: Color(0xFFE05A5A)),
                      tooltip: 'Verlauf löschen',
                      onPressed: () => userProv.clearHistory(),
                    ),
                ],
              ),
            ),
            const Divider(color: AppTheme.divider, height: 1),
            Expanded(
              child: history.isEmpty
                  ? const _EmptyHistory()
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: history.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, i) => _HistoryTile(
                        entry: history[i],
                        onTap: () => onPick(history[i].result),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  final HistoryEntry entry;
  final VoidCallback onTap;

  const _HistoryTile({required this.entry, required this.onTap});

  String get _time {
    final d = DateTime.fromMillisecondsSinceEpoch(entry.timestamp);
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}.${two(d.month)}. ${two(d.hour)}:${two(d.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.goldDark, width: 0.5),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${entry.expression} =',
                    style: const TextStyle(
                        color: AppTheme.textSecondary, fontSize: 13),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    entry.result,
                    style: const TextStyle(
                      color: AppTheme.gold,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _time,
                    style: TextStyle(
                      color: AppTheme.textSecondary.withValues(alpha: 0.7),
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.north_east, color: AppTheme.goldDark, size: 18),
          ],
        ),
      ),
    );
  }
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🧾', style: TextStyle(fontSize: 44)),
            const SizedBox(height: 12),
            const Text(
              'Noch kein Verlauf',
              style: TextStyle(
                color: AppTheme.gold,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Freigeschaltete Resultate erscheinen hier — tippe sie an, um weiterzurechnen.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
