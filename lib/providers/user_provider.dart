import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/history_entry.dart';
import '../models/profile_comment.dart';
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

  UserModel? userById(String id) {
    for (final account in _accounts.values) {
      if (account.user.id == id) return account.user;
    }
    return null;
  }

  /// Alle Benutzer, absteigend nach ausgegebenem echten Geld sortiert.
  List<UserModel> get leaderboard {
    final list = _accounts.values.map((a) => a.user).toList()
      ..sort((a, b) => b.totalSpentMinor.compareTo(a.totalSpentMinor));
    return List.unmodifiable(list);
  }

  int leaderboardRankOf(String userId) {
    final index = leaderboard.indexWhere((user) => user.id == userId);
    return index == -1 ? 0 : index + 1;
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
    _accounts[mail] = _Account.withPassword(password: password, user: user);
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
    if (!account.verifyPassword(password)) return 'Wrong password.';
    if (account.needsPasswordMigration) {
      _accounts[mail] =
          _Account.withPassword(password: password, user: account.user);
    }

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

  /// Speichert die frei personalisierbaren Profilinhalte.
  Future<void> updateProfileDetails({
    String? profileTitle,
    String? bio,
    List<String>? links,
    int? profileAccentIndex,
  }) async {
    final user = currentUser;
    if (user == null) return;

    if (profileTitle != null) {
      user.profileTitle = profileTitle.trim();
    }
    if (bio != null) {
      user.bio = bio.trim();
    }
    if (links != null) {
      user.links = links
          .map((link) => link.trim())
          .where((link) => link.isNotEmpty)
          .take(4)
          .toList();
    }
    if (profileAccentIndex != null) {
      user.profileAccentIndex = profileAccentIndex;
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

  Future<void> addProfileComment({
    required String targetUserId,
    required String text,
  }) async {
    final author = currentUser;
    final target = userById(targetUserId);
    final trimmed = text.trim();
    if (author == null || target == null || trimmed.isEmpty) return;

    target.profileComments.insert(
      0,
      ProfileComment(
        id: '${DateTime.now().microsecondsSinceEpoch}_${author.id}',
        authorId: author.id,
        authorName: author.username,
        authorAvatar: author.avatar,
        authorAvatarPath: author.avatarPath,
        text: trimmed,
        timestamp: DateTime.now().millisecondsSinceEpoch,
      ),
    );
    if (target.profileComments.length > 100) {
      target.profileComments.removeRange(100, target.profileComments.length);
    }

    await _persist();
    notifyListeners();
  }

  Future<void> replyToProfileComment({
    required String targetUserId,
    required String commentId,
    required String reply,
  }) async {
    final owner = currentUser;
    final target = userById(targetUserId);
    final trimmed = reply.trim();
    if (owner == null ||
        target == null ||
        owner.id != target.id ||
        trimmed.isEmpty) {
      return;
    }

    for (final comment in target.profileComments) {
      if (comment.id == commentId) {
        comment.ownerReply = trimmed;
        comment.ownerReplyTimestamp = DateTime.now().millisecondsSinceEpoch;
        break;
      }
    }

    await _persist();
    notifyListeners();
  }

  /// Ändert den Benutzernamen gegen Bezahlung. Der Betrag zählt zum
  /// ausgegebenen Geld (Rangliste), aber NICHT zum Resultat-Zähler.
  /// Die Zahlung selbst läuft vorher über die UI (PaymentService).
  Future<void> changeUsername(String newUsername, int amountMinor) async {
    final user = currentUser;
    if (user == null) return;
    final name = newUsername.trim();
    if (name.isEmpty) return;

    user.username = name;
    user.totalSpentMinor += amountMinor;
    user.usernameChanges += 1;

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
    // Operator-Nutzung für Achievements zählen (pro Rechnung max. 1 je Operator).
    for (final op in const ['+', '-', '*', '/']) {
      if (expression.contains(op)) {
        user.operatorCounts[op] = (user.operatorCounts[op] ?? 0) + 1;
      }
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

/// Bündelt Passwort-Hash und Benutzerdaten eines Kontos (nur lokal, Fake-Login).
class _Account {
  final String passwordHash;
  final String passwordSalt;
  final String? legacyPassword;
  final UserModel user;

  _Account({
    required this.passwordHash,
    required this.passwordSalt,
    required this.user,
    this.legacyPassword,
  });

  factory _Account.withPassword({
    required String password,
    required UserModel user,
  }) {
    final salt = _PasswordHasher.createSalt();
    return _Account(
      passwordHash: _PasswordHasher.hash(password, salt),
      passwordSalt: salt,
      user: user,
    );
  }

  bool get needsPasswordMigration => legacyPassword != null;

  bool verifyPassword(String password) {
    if (legacyPassword != null) return legacyPassword == password;
    return passwordHash == _PasswordHasher.hash(password, passwordSalt);
  }

  Map<String, dynamic> toJson() => {
        'passwordHash': passwordHash,
        'passwordSalt': passwordSalt,
        'user': user.toJson(),
      };

  factory _Account.fromJson(Map<String, dynamic> json) {
    final hash = json['passwordHash'] as String?;
    final salt = json['passwordSalt'] as String?;
    final legacyPassword = json['password'] as String?;
    final user = UserModel.fromJson(json['user'] as Map<String, dynamic>);

    if (hash != null && salt != null) {
      return _Account(passwordHash: hash, passwordSalt: salt, user: user);
    }

    return _Account(
      passwordHash: '',
      passwordSalt: '',
      legacyPassword: legacyPassword,
      user: user,
    );
  }
}

class _PasswordHasher {
  static final Random _random = Random.secure();

  static String createSalt() {
    final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
    return base64UrlEncode(bytes);
  }

  static String hash(String password, String salt) {
    final bytes = utf8.encode('$salt:$password');
    return sha256.convert(bytes).toString();
  }
}
