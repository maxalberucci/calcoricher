import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Ein Rang-Tier, freigeschaltet ab einem ausgegebenen Gesamtbetrag.
class Rank {
  final String name;
  final int thresholdMinor;
  final Color color;
  final IconData icon;

  const Rank(this.name, this.thresholdMinor, this.color, this.icon);
}

/// Rang-Leiter (aufsteigend). Schwellen in Minor-Units (Cent/Rappen).
const List<Rank> kRanks = [
  Rank('Pauper', 0, Color(0xFF9A968B), Icons.savings_outlined),
  Rank('Spender', 1000, Color(0xFFB0764A), Icons.paid_outlined), //   10.00
  Rank('Patron', 10000, AppTheme.bronze, Icons.workspace_premium), //  100.00
  Rank('Magnate', 100000, AppTheme.silver, Icons.diamond_outlined), // 1000.00
  Rank('Tycoon', 1000000, AppTheme.gold, Icons.diamond), //          10'000.00
  Rank('Oligarch', 10000000, Color(0xFF7FE3FF), Icons.auto_awesome), // 100'000
  Rank('Croesus', 100000000, Color(0xFFE9D8FF), Icons.emoji_events), // 1 Mio.
];

/// Aktueller Rang für einen ausgegebenen Betrag.
Rank rankForSpent(int minor) {
  var current = kRanks.first;
  for (final r in kRanks) {
    if (minor >= r.thresholdMinor) {
      current = r;
    } else {
      break;
    }
  }
  return current;
}

/// Nächsthöherer Rang oder null, falls bereits am Maximum.
Rank? nextRankAfter(Rank rank) {
  final i = kRanks.indexOf(rank);
  return (i >= 0 && i < kRanks.length - 1) ? kRanks[i + 1] : null;
}

/// Fortschritt (0..1) vom aktuellen zum nächsten Rang.
double rankProgress(int minor) {
  final current = rankForSpent(minor);
  final next = nextRankAfter(current);
  if (next == null) return 1.0;
  final span = next.thresholdMinor - current.thresholdMinor;
  if (span <= 0) return 1.0;
  return ((minor - current.thresholdMinor) / span).clamp(0.0, 1.0);
}
