import 'package:flutter/material.dart';
import '../models/user_model.dart';

/// Eine Auszeichnung, die aus dem Benutzerzustand berechnet wird.
class Achievement {
  final String id;
  final String title;
  final String description;
  final IconData icon;
  final bool Function(UserModel) _unlocked;

  /// Optionaler Fortschritt (aktueller Wert / Ziel) für eine Anzeige.
  final int Function(UserModel)? _current;
  final int? target;

  const Achievement({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required bool Function(UserModel) unlocked,
    int Function(UserModel)? current,
    this.target,
  })  : _unlocked = unlocked,
        _current = current;

  bool isUnlocked(UserModel u) => _unlocked(u);

  /// Fortschritt 0..1, falls Ziel definiert ist; sonst 0/1 nach Status.
  double progress(UserModel u) {
    final current = _current;
    if (current == null || target == null || target == 0) {
      return isUnlocked(u) ? 1.0 : 0.0;
    }
    return (current(u) / target!).clamp(0.0, 1.0);
  }

  String? progressLabel(UserModel u) {
    final current = _current;
    if (current == null || target == null) return null;
    final c = current(u).clamp(0, target!);
    return '$c / $target';
  }
}

/// Alle verfügbaren Auszeichnungen.
final List<Achievement> kAchievements = [
  Achievement(
    id: 'first',
    title: 'First Reveal',
    description: 'Unlock your first result',
    icon: Icons.lock_open_rounded,
    unlocked: (u) => u.unlockedResultsCount >= 1,
    current: (u) => u.unlockedResultsCount,
    target: 1,
  ),
  Achievement(
    id: 'ten',
    title: 'Calculating Habit',
    description: 'Unlock 10 results',
    icon: Icons.calculate,
    unlocked: (u) => u.unlockedResultsCount >= 10,
    current: (u) => u.unlockedResultsCount,
    target: 10,
  ),
  Achievement(
    id: 'hundred',
    title: 'Number Cruncher',
    description: 'Unlock 100 results',
    icon: Icons.functions,
    unlocked: (u) => u.unlockedResultsCount >= 100,
    current: (u) => u.unlockedResultsCount,
    target: 100,
  ),
  Achievement(
    id: 'plus',
    title: 'Plus Patron',
    description: 'Use + in 10 calculations',
    icon: Icons.add,
    unlocked: (u) => u.operatorCount('+') >= 10,
    current: (u) => u.operatorCount('+'),
    target: 10,
  ),
  Achievement(
    id: 'times',
    title: 'Big Multiplier',
    description: 'Use × in 10 calculations',
    icon: Icons.close,
    unlocked: (u) => u.operatorCount('*') >= 10,
    current: (u) => u.operatorCount('*'),
    target: 10,
  ),
  Achievement(
    id: 'rename',
    title: 'Identity Crisis',
    description: 'Pay to change your name',
    icon: Icons.badge,
    unlocked: (u) => u.usernameChanges >= 1,
    current: (u) => u.usernameChanges,
    target: 1,
  ),
  Achievement(
    id: 'rename3',
    title: 'Shapeshifter',
    description: 'Change your name 3 times',
    icon: Icons.theater_comedy,
    unlocked: (u) => u.usernameChanges >= 3,
    current: (u) => u.usernameChanges,
    target: 3,
  ),
  Achievement(
    id: 'photo',
    title: 'Picture Perfect',
    description: 'Set a profile photo',
    icon: Icons.photo_camera,
    unlocked: (u) => u.avatarPath != null && u.avatarPath!.isNotEmpty,
  ),
  Achievement(
    id: 'spender',
    title: 'Big Spender',
    description: 'Spend a fortune in total',
    icon: Icons.local_fire_department,
    unlocked: (u) => u.totalSpentMinor >= 100000,
    current: (u) => u.totalSpentMinor,
    target: 100000,
  ),
  Achievement(
    id: 'whale',
    title: 'Whale',
    description: 'Spend a small empire in total',
    icon: Icons.water_drop,
    unlocked: (u) => u.totalSpentMinor >= 1000000,
    current: (u) => u.totalSpentMinor,
    target: 1000000,
  ),
];

int unlockedCount(UserModel u) =>
    kAchievements.where((a) => a.isUnlocked(u)).length;
