import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';

class UserProvider extends ChangeNotifier {
  static const _keyCurrentUser = 'current_user';
  static const _keyLeaderboard = 'leaderboard';

  UserModel? _currentUser;
  List<UserModel> _leaderboard = [];

  UserModel? get currentUser => _currentUser;
  List<UserModel> get leaderboard => List.unmodifiable(_leaderboard);
  bool get hasUser => _currentUser != null;

  /// Load persisted data on startup.
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();

    final userJson = prefs.getString(_keyCurrentUser);
    if (userJson != null) {
      _currentUser = UserModel.fromJson(jsonDecode(userJson));
    }

    final boardJson = prefs.getString(_keyLeaderboard);
    if (boardJson != null) {
      final List decoded = jsonDecode(boardJson);
      _leaderboard = decoded.map((e) => UserModel.fromJson(e)).toList();
    }

    notifyListeners();
  }

  /// Create or update the current user with the given name.
  Future<void> setUser(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;

    // Check if the user already exists in the leaderboard.
    final existing = _leaderboard.where((u) => u.name == trimmed).firstOrNull;
    _currentUser = existing ?? UserModel(name: trimmed);

    await _save();
    notifyListeners();
  }

  /// Deduct coins for showing a result. Returns true on success.
  Future<bool> spendCoins() async {
    final user = _currentUser;
    if (user == null) return false;

    final price = user.nextPrice;
    if (user.coins < price) return false;

    _currentUser = user.copyWith(
      coins: user.coins - price,
      spentCoins: user.spentCoins + price,
      resultsShown: user.resultsShown + 1,
    );

    await _save();
    notifyListeners();
    return true;
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    final user = _currentUser;
    if (user == null) return;

    await prefs.setString(_keyCurrentUser, jsonEncode(user.toJson()));
    _updateLeaderboard(user);
    await prefs.setString(
      _keyLeaderboard,
      jsonEncode(_leaderboard.map((u) => u.toJson()).toList()),
    );
  }

  void _updateLeaderboard(UserModel updated) {
    final idx = _leaderboard.indexWhere((u) => u.name == updated.name);
    if (idx >= 0) {
      _leaderboard[idx] = updated;
    } else {
      _leaderboard.add(updated);
    }
    // Sort by most coins spent, descending.
    _leaderboard.sort((a, b) => b.spentCoins.compareTo(a.spentCoins));
  }
}
