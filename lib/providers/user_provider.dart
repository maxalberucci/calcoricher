import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/admin_config.dart';
import '../models/history_entry.dart';
import '../models/profile_comment.dart';
import '../models/user_model.dart';
import '../utils/url_safety.dart';

/// Sortierkriterien der Rangliste.
enum LeaderboardSort { spent, results, highestUnlock }

/// Serverseitige Längen-Obergrenzen (Defense-in-Depth). Die UI begrenzt
/// Eingaben bereits, aber der Provider ist die eigentliche Vertrauensgrenze:
/// gespeicherte Daten könnten lokal manipuliert oder über künftige Codepfade
/// gesetzt werden. Diese Caps verhindern Storage-/UI-Missbrauch durch
/// überlange Inhalte.
class _Limits {
  static const int username = 80;
  static const int profileTitle = 120;
  static const int bio = 1000;
  static const int link = 300;
  static const int maxLinks = 4;
  static const int comment = 500;
  static const int reply = 500;
}

/// Schneidet einen getrimmten String hart auf [maxCodeUnits] zu, ohne ein
/// Surrogatpaar in der Mitte zu zerteilen (sonst entstünde ungültiges JSON).
String _clampText(String value, int maxCodeUnits) {
  final trimmed = value.trim();
  if (trimmed.length <= maxCodeUnits) return trimmed;
  var end = maxCodeUnits;
  final unit = trimmed.codeUnitAt(end - 1);
  if (unit >= 0xD800 && unit <= 0xDBFF) end -= 1; // High-Surrogate -> 1 zurück.
  return trimmed.substring(0, end);
}

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

  /// Alle Benutzer, absteigend nach ausgegebenem echten Geld sortiert
  /// (Standard-Rangliste, treibt auch den Rang).
  List<UserModel> get leaderboard => leaderboardBy(LeaderboardSort.spent);

  /// Rangliste nach dem gewählten Kriterium (absteigend).
  List<UserModel> leaderboardBy(LeaderboardSort sort) {
    int compare(UserModel a, UserModel b) {
      switch (sort) {
        case LeaderboardSort.spent:
          return b.totalSpentMinor.compareTo(a.totalSpentMinor);
        case LeaderboardSort.results:
          final byResults =
              b.unlockedResultsCount.compareTo(a.unlockedResultsCount);
          return byResults != 0
              ? byResults
              : b.totalSpentMinor.compareTo(a.totalSpentMinor);
        case LeaderboardSort.highestUnlock:
          final byUnlock = b.highestUnlockMinor.compareTo(a.highestUnlockMinor);
          return byUnlock != 0
              ? byUnlock
              : b.totalSpentMinor.compareTo(a.totalSpentMinor);
      }
    }

    final list = _accounts.values.map((a) => a.user).toList()..sort(compare);
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
    final name = _clampText(username, _Limits.username);
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
      id: _generateUserId(),
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
    if (account.user.isBanned) {
      return 'This account has been banned.';
    }
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
      user.profileTitle = _clampText(profileTitle, _Limits.profileTitle);
    }
    if (bio != null) {
      user.bio = _clampText(bio, _Limits.bio);
    }
    if (links != null) {
      // Nur sichere http(s)-Links speichern (siehe [UrlSafety]).
      user.links = links
          .map(UrlSafety.normalize)
          .whereType<String>()
          .map((link) => _clampText(link, _Limits.link))
          .take(_Limits.maxLinks)
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
    final trimmed = _clampText(text, _Limits.comment);
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
    target.unreadCommentCount += 1;

    await _persist();
    notifyListeners();
  }

  /// Anzahl noch nicht angesehener Kommentare des aktuellen Benutzers (Badge).
  int get unreadCommentCount => currentUser?.unreadCommentCount ?? 0;

  /// Setzt das Kommentar-Badge des aktuellen Benutzers zurück (alles gesehen).
  Future<void> markProfileCommentsSeen() async {
    final user = currentUser;
    if (user == null || user.unreadCommentCount == 0) return;
    user.unreadCommentCount = 0;
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
    final trimmed = _clampText(reply, _Limits.reply);
    if (owner == null ||
        target == null ||
        owner.id != target.id ||
        trimmed.isEmpty) {
      return;
    }

    for (final comment in target.profileComments) {
      if (comment.id == commentId) {
        final isNewReply = comment.ownerReply == null;
        comment.ownerReply = trimmed;
        comment.ownerReplyTimestamp = DateTime.now().millisecondsSinceEpoch;
        // Den Verfasser des Kommentars über die (erste) Antwort benachrichtigen.
        final author = userById(comment.authorId);
        if (isNewReply && author != null && author.id != owner.id) {
          author.unreadReplyCount += 1;
        }
        break;
      }
    }

    await _persist();
    notifyListeners();
  }

  /// Anzahl noch nicht angesehener Antworten auf eigene Kommentare (Badge).
  int get unreadReplyCount => currentUser?.unreadReplyCount ?? 0;

  /// Antworten auf die Kommentare des aktuellen Benutzers (neueste zuerst).
  List<ReplyNotification> get repliesToMyComments {
    final me = currentUser;
    if (me == null) return const [];

    final result = <ReplyNotification>[];
    for (final account in _accounts.values) {
      final owner = account.user;
      for (final comment in owner.profileComments) {
        if (comment.authorId == me.id &&
            comment.ownerReply != null &&
            comment.ownerReply!.trim().isNotEmpty) {
          result.add(ReplyNotification(profileOwner: owner, comment: comment));
        }
      }
    }
    result.sort((a, b) => (b.comment.ownerReplyTimestamp ?? 0)
        .compareTo(a.comment.ownerReplyTimestamp ?? 0));
    return result;
  }

  /// Setzt das Antwort-Badge des aktuellen Benutzers zurück (alles gesehen).
  Future<void> markRepliesSeen() async {
    final user = currentUser;
    if (user == null || user.unreadReplyCount == 0) return;
    user.unreadReplyCount = 0;
    await _persist();
    notifyListeners();
  }

  // --- Reports & Admin -----------------------------------------------------

  /// Ob das aktuell angemeldete Konto Admin-Rechte hat.
  bool get isAdmin => AdminConfig.isAdmin(currentUser?.email);

  /// Meldet einen Kommentar (jeder angemeldete Nutzer darf melden, einmal je
  /// Kommentar). Gibt `true` zurück, wenn die Meldung neu gespeichert wurde.
  Future<bool> reportProfileComment({
    required String targetUserId,
    required String commentId,
    required String reason,
  }) async {
    final reporter = currentUser;
    final target = userById(targetUserId);
    if (reporter == null || target == null) return false;

    for (final comment in target.profileComments) {
      if (comment.id == commentId) {
        if (comment.isReportedBy(reporter.id)) return false;
        comment.reports.add(CommentReport(
          reporterId: reporter.id,
          reporterName: reporter.username,
          reason: reason.trim(),
          timestamp: DateTime.now().millisecondsSinceEpoch,
        ));
        await _persist();
        notifyListeners();
        return true;
      }
    }
    return false;
  }

  /// Alle gemeldeten Kommentare (für das Admin-Tool), am meisten gemeldete
  /// zuerst.
  List<ReportedComment> get reportedComments {
    final result = <ReportedComment>[];
    for (final account in _accounts.values) {
      final owner = account.user;
      for (final comment in owner.profileComments) {
        if (comment.reports.isNotEmpty) {
          result.add(ReportedComment(profileOwner: owner, comment: comment));
        }
      }
    }
    result.sort(
        (a, b) => b.comment.reports.length.compareTo(a.comment.reports.length));
    return result;
  }

  /// Anzahl gemeldeter Kommentare (für ein Admin-Badge).
  int get reportedCommentCount => isAdmin ? reportedComments.length : 0;

  /// Alle Konten, absteigend nach ausgegebenem Geld (für das User-Management).
  List<UserModel> get allUsers => leaderboardBy(LeaderboardSort.spent);

  /// Aggregierte Kennzahlen für das Admin-Dashboard.
  AdminStats get adminStats {
    var comments = 0;
    var reports = 0;
    var spent = 0;
    var results = 0;
    var banned = 0;
    for (final account in _accounts.values) {
      final user = account.user;
      comments += user.profileComments.length;
      reports += user.profileComments.fold(0, (sum, c) => sum + c.reports.length);
      spent += user.totalSpentMinor;
      results += user.unlockedResultsCount;
      if (user.isBanned) banned += 1;
    }
    return AdminStats(
      users: _accounts.length,
      comments: comments,
      reports: reports,
      totalSpentMinor: spent,
      results: results,
      banned: banned,
    );
  }

  /// Admin: sperrt/entsperrt ein Konto. Admin-Konten können nicht gebannt werden.
  Future<void> adminSetBanned({
    required String userId,
    required bool banned,
  }) async {
    if (!isAdmin) return;
    final user = userById(userId);
    if (user == null) return;
    if (AdminConfig.isAdmin(user.email)) return; // Admins sind unantastbar.
    user.isBanned = banned;
    await _persist();
    notifyListeners();
  }

  /// Admin: löscht einen gemeldeten Kommentar endgültig.
  Future<void> adminDeleteComment({
    required String targetUserId,
    required String commentId,
  }) async {
    if (!isAdmin) return;
    final target = userById(targetUserId);
    if (target == null) return;
    target.profileComments.removeWhere((c) => c.id == commentId);
    await _persist();
    notifyListeners();
  }

  /// Admin: verwirft die Meldungen eines Kommentars (Kommentar bleibt bestehen).
  Future<void> adminDismissReports({
    required String targetUserId,
    required String commentId,
  }) async {
    if (!isAdmin) return;
    final target = userById(targetUserId);
    if (target == null) return;
    for (final comment in target.profileComments) {
      if (comment.id == commentId) {
        comment.reports.clear();
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
    final name = _clampText(newUsername, _Limits.username);
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
    if (amountMinor > user.highestUnlockMinor) {
      user.highestUnlockMinor = amountMinor;
    }
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

  static final Random _idRandom = Random();

  /// Eindeutige Benutzer-ID – auch bei mehreren Registrierungen pro Millisekunde.
  String _generateUserId() =>
      '${DateTime.now().microsecondsSinceEpoch}_${_idRandom.nextInt(1 << 31)}';

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    final map = _accounts.map((k, v) => MapEntry(k, v.toJson()));
    await prefs.setString(_keyAccounts, jsonEncode(map));
    if (_currentEmail != null) {
      await prefs.setString(_keyCurrentEmail, _currentEmail!);
    }
  }
}

/// Eine Antwort des Profil-Besitzers auf einen eigenen Kommentar.
class ReplyNotification {
  final UserModel profileOwner;
  final ProfileComment comment;

  const ReplyNotification({required this.profileOwner, required this.comment});
}

/// Ein gemeldeter Kommentar samt Profil, auf dem er steht (für das Admin-Tool).
class ReportedComment {
  final UserModel profileOwner;
  final ProfileComment comment;

  const ReportedComment({required this.profileOwner, required this.comment});
}

/// Aggregierte Kennzahlen für das Admin-Dashboard.
class AdminStats {
  final int users;
  final int comments;
  final int reports;
  final int totalSpentMinor;
  final int results;
  final int banned;

  const AdminStats({
    required this.users,
    required this.comments,
    required this.reports,
    required this.totalSpentMinor,
    required this.results,
    required this.banned,
  });
}

/// Bündelt Passwort-Hash und Benutzerdaten eines Kontos (nur lokal, Fake-Login).
class _Account {
  static const String algoPbkdf2 = 'pbkdf2';
  static const String algoSha256 = 'sha256';

  final String passwordHash;
  final String passwordSalt;
  final String passwordAlgo;
  final int iterations;
  final String? legacyPassword;
  final UserModel user;

  _Account({
    required this.passwordHash,
    required this.passwordSalt,
    required this.passwordAlgo,
    required this.iterations,
    required this.user,
    this.legacyPassword,
  });

  factory _Account.withPassword({
    required String password,
    required UserModel user,
  }) {
    final salt = _PasswordHasher.createSalt();
    return _Account(
      passwordHash: _PasswordHasher.hashPbkdf2(password, salt),
      passwordSalt: salt,
      passwordAlgo: algoPbkdf2,
      iterations: _PasswordHasher.iterations,
      user: user,
    );
  }

  /// Konten mit Klartext-Passwort oder altem SHA-256 werden beim nächsten
  /// erfolgreichen Login auf PBKDF2 angehoben.
  bool get needsPasswordMigration =>
      legacyPassword != null || passwordAlgo != algoPbkdf2;

  bool verifyPassword(String password) {
    if (legacyPassword != null) {
      return _PasswordHasher.constantTimeEquals(legacyPassword!, password);
    }
    final computed = passwordAlgo == algoPbkdf2
        ? _PasswordHasher.hashPbkdf2(password, passwordSalt, rounds: iterations)
        : _PasswordHasher.hashLegacySha256(password, passwordSalt);
    return _PasswordHasher.constantTimeEquals(computed, passwordHash);
  }

  Map<String, dynamic> toJson() => {
        'passwordHash': passwordHash,
        'passwordSalt': passwordSalt,
        'passwordAlgo': passwordAlgo,
        'iterations': iterations,
        'user': user.toJson(),
      };

  factory _Account.fromJson(Map<String, dynamic> json) {
    final hash = json['passwordHash'] as String?;
    final salt = json['passwordSalt'] as String?;
    final algo = json['passwordAlgo'] as String?;
    final iterations =
        json['iterations'] as int? ?? _PasswordHasher.iterations;
    final legacyPassword = json['password'] as String?;
    final user = UserModel.fromJson(json['user'] as Map<String, dynamic>);

    if (hash != null && salt != null && hash.isNotEmpty && salt.isNotEmpty) {
      return _Account(
        passwordHash: hash,
        passwordSalt: salt,
        // Fehlender Marker = altes Schema (salted SHA-256).
        passwordAlgo: algo ?? algoSha256,
        iterations: iterations,
        user: user,
      );
    }

    return _Account(
      passwordHash: '',
      passwordSalt: '',
      passwordAlgo: algoSha256,
      iterations: iterations,
      legacyPassword: legacyPassword,
      user: user,
    );
  }
}

class _PasswordHasher {
  static final Random _random = Random.secure();

  /// Iterationen für PBKDF2. Bewusst hoch, um Brute-Force teuer zu machen
  /// (die Hashes liegen lokal im Klartext-Storage).
  static const int iterations = 120000;
  static const int _keyLengthBytes = 32;

  static String createSalt() {
    final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
    return base64UrlEncode(bytes);
  }

  /// Aktuelles Verfahren: PBKDF2-HMAC-SHA256 (key-stretching).
  static String hashPbkdf2(
    String password,
    String salt, {
    int rounds = iterations,
  }) {
    final key = _pbkdf2(
      utf8.encode(password),
      utf8.encode(salt),
      rounds,
      _keyLengthBytes,
    );
    return base64Encode(key);
  }

  /// Altes Verfahren (nur noch zur Verifikation/Migration bestehender Konten).
  static String hashLegacySha256(String password, String salt) =>
      sha256.convert(utf8.encode('$salt:$password')).toString();

  /// Konstant-zeitiger Vergleich, um Timing-Seitenkanäle zu vermeiden.
  static bool constantTimeEquals(String a, String b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return diff == 0;
  }

  static List<int> _pbkdf2(
    List<int> password,
    List<int> salt,
    int rounds,
    int keyLen,
  ) {
    final hmac = Hmac(sha256, password);
    final out = <int>[];
    var block = 1;
    while (out.length < keyLen) {
      out.addAll(_pbkdf2Block(hmac, salt, rounds, block));
      block++;
    }
    return out.sublist(0, keyLen);
  }

  static List<int> _pbkdf2Block(
    Hmac hmac,
    List<int> salt,
    int rounds,
    int blockIndex,
  ) {
    final indexBytes = [
      (blockIndex >> 24) & 0xff,
      (blockIndex >> 16) & 0xff,
      (blockIndex >> 8) & 0xff,
      blockIndex & 0xff,
    ];
    var u = hmac.convert([...salt, ...indexBytes]).bytes;
    final result = List<int>.from(u);
    for (var i = 1; i < rounds; i++) {
      u = hmac.convert(u).bytes;
      for (var j = 0; j < result.length; j++) {
        result[j] ^= u[j];
      }
    }
    return result;
  }
}
