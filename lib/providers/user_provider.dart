import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/history_entry.dart';
import '../models/user_model.dart';

/// Verwaltet Konten (Fake-Login), die aktuelle Sitzung und die Rangliste.
///
/// Alle Daten liegen lokal in [SharedPreferences]. Ein Konto bündelt Passwort
/// und Benutzerdaten; die Rangliste wird aus allen Konten abgeleitet.
class UserProvider extends ChangeNotifier {
  static const _keyAccounts = 'accounts_v2';
  static const _keyCurrentEmail = 'current_email';

  final Map<String, _Account> _accounts = {};
  String? _currentEmail;
  bool _initialized = false;

  bool get isInitialized => _initialized;
  bool get hasUser =>
      _currentEmail != null && _accounts.containsKey(_currentEmail);
  UserModel? get currentUser => hasUser ? _accounts[_currentEmail]!.user : null;

  /// Alle Benutzer, absteigend nach ausgegebenem echten Geld sortiert.
  List<UserModel> get leaderboard {
    final list = _accounts.values.map((a) => a.user).toList()
      ..sort((a, b) => b.totalSpentMinor.compareTo(a.totalSpentMinor));
    return List.unmodifiable(list);
  }

  /// Lädt gespeicherte Konten und die letzte Sitzung beim Start.
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();

    final raw = prefs.getString(_keyAccounts);
    if (raw != null) {
      final Map<String, dynamic> decoded = jsonDecode(raw);
      decoded.forEach((email, value) {
        _accounts[email] = _Account.fromJson(value);
      });
    }

    final savedEmail = prefs.getString(_keyCurrentEmail);
    if (savedEmail != null && _accounts.containsKey(savedEmail)) {
      _currentEmail = savedEmail;
    }

    _initialized = true;
    notifyListeners();
  }

  /// Registriert ein neues Konto und meldet es direkt an.
  /// Gibt bei Erfolg `null` zurück, sonst eine Fehlermeldung.
  Future<String?> register({
    required String username,
    required String email,
    required String password,
  }) async {
    final name = username.trim();
    final mail = email.trim().toLowerCase();

    if (name.isEmpty || mail.isEmpty || password.isEmpty) {
      return 'Please fill in all fields.';
    }
    if (name.length < 2) return 'The name needs at least 2 characters.';
    if (!mail.contains('@') || !mail.contains('.')) {
      return 'Please enter a valid email.';
    }
    if (password.length < 4) {
      return 'The password needs at least 4 characters.';
    }
    if (_accounts.containsKey(mail)) {
      return 'This email is already registered.';
    }

    final user = UserModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      username: name,
      email: mail,
    );
    _accounts[mail] = _Account(password: password, user: user);
    _currentEmail = mail;

    await _persist();
    notifyListeners();
    return null;
  }

  /// Meldet einen bestehenden Benutzer an.
  /// Gibt bei Erfolg `null` zurück, sonst eine Fehlermeldung.
  Future<String?> login({
    required String email,
    required String password,
  }) async {
    final mail = email.trim().toLowerCase();
    final account = _accounts[mail];

    if (account == null) return 'No account found with this email.';
    if (account.password != password) return 'Wrong password.';

    _currentEmail = mail;
    await _persist();
    notifyListeners();
    return null;
  }

  Future<void> logout() async {
    _currentEmail = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyCurrentEmail);
    notifyListeners();
  }

  /// Aktualisiert Benutzername und/oder Emoji-Avatar des aktuellen Benutzers.
  /// Die Wahl eines Emojis entfernt ein zuvor gewähltes Foto.
  Future<void> updateProfile({String? username, String? avatar}) async {
    final user = currentUser;
    if (user == null) return;

    if (username != null && username.trim().isNotEmpty) {
      user.username = username.trim();
    }
    if (avatar != null) {
      user.avatar = avatar;
      user.avatarPath = null;
    }

    await _persist();
    notifyListeners();
  }

  /// Setzt ein selbst gewähltes Profilbild (Kamera/Galerie).
  Future<void> updateProfilePhoto(String path) async {
    final user = currentUser;
    if (user == null) return;
    user.avatarPath = path;
    await _persist();
    notifyListeners();
  }

  /// Verbucht eine erfolgreiche (echte) Zahlung: erhöht den ausgegebenen Betrag
  /// und den Zähler (verdoppelt den nächsten Preis) und legt die freigeschaltete
  /// Rechnung im Verlauf ab (neueste zuerst, max. 50).
  Future<void> recordPurchase({
    required int amountMinor,
    required String expression,
    required String result,
  }) async {
    final user = currentUser;
    if (user == null) return;

    user.totalSpentMinor += amountMinor;
    user.unlockedResultsCount += 1;
    user.history.insert(
      0,
      HistoryEntry(
        expression: expression,
        result: result,
        timestamp: DateTime.now().millisecondsSinceEpoch,
      ),
    );
    if (user.history.length > 50) {
      user.history.removeRange(50, user.history.length);
    }

    await _persist();
    notifyListeners();
  }

  /// Löscht den Verlauf des aktuellen Benutzers.
  Future<void> clearHistory() async {
    final user = currentUser;
    if (user == null) return;
    user.history.clear();
    await _persist();
    notifyListeners();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    final map = _accounts.map((k, v) => MapEntry(k, v.toJson()));
    await prefs.setString(_keyAccounts, jsonEncode(map));
    if (_currentEmail != null) {
      await prefs.setString(_keyCurrentEmail, _currentEmail!);
    }
  }
}

/// Bündelt Passwort und Benutzerdaten eines Kontos (nur lokal, Fake-Login).
class _Account {
  final String password;
  final UserModel user;

  _Account({required this.password, required this.user});

  Map<String, dynamic> toJson() => {
        'password': password,
        'user': user.toJson(),
      };

  factory _Account.fromJson(Map<String, dynamic> json) => _Account(
        password: json['password'] as String,
        user: UserModel.fromJson(json['user'] as Map<String, dynamic>),
      );
}
