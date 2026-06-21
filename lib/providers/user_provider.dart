import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/admin_config.dart';
import '../models/feed_item.dart';
import '../models/history_entry.dart';
import '../models/profile_comment.dart';
import '../models/user_model.dart';
import '../payments/payment_config.dart';
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
  static const _keyRooms = 'product_rooms_v1';
  static const _keyActiveChallenge = 'active_challenge_v1';
  static const _keyActiveCharity = 'active_charity_v1';

  final Map<String, _Account> _accounts = {};
  final List<RichRoom> _rooms = [];
  String? _currentEmail;
  String? _activeChallengeSlug;
  String? _activeCharityCampaignId;
  bool _initialized = false;

  bool get isInitialized => _initialized;
  bool get hasUser =>
      _currentEmail != null && _accounts.containsKey(_currentEmail);
  UserModel? get currentUser => hasUser ? _accounts[_currentEmail]!.user : null;
  List<RichRoom> get rooms => List.unmodifiable(_rooms);
  String? get activeChallengeSlug => _activeChallengeSlug;
  String? get activeCharityCampaignId => _activeCharityCampaignId;

  DailyRichQuestion get dailyRichQuestion {
    final now = DateTime.now();
    final date = _dateKey(now);
    final seed = int.tryParse(date.replaceAll('-', '')) ?? 20260621;
    final left = 10 + (seed % 41);
    final right = 2 + ((seed ~/ 7) % 17);
    return DailyRichQuestion(
      date: date,
      title: 'Daily Rich Question',
      expression: '$left * $right',
    );
  }

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

  List<FeedItem> get publicFeed {
    final items = <FeedItem>[];
    for (final account in _accounts.values) {
      for (final entry in account.user.history) {
        items.add(account.user.feedItemFor(entry));
      }
    }
    items.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return List.unmodifiable(items);
  }

  Future<RichRoom> createRoom({required String title}) async {
    final user = currentUser;
    final cleanedTitle = _clampText(title, 80);
    final room = RichRoom(
      id: _generateUserId(),
      code: _roomCode(),
      title: cleanedTitle.isEmpty ? 'Private Rich Room' : cleanedTitle,
      ownerId: user?.id ?? '',
      members: user == null ? const [] : [user.id],
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );
    _rooms.insert(0, room);
    await _persist();
    notifyListeners();
    return room;
  }

  Future<void> joinRoom(String code) async {
    final user = currentUser;
    if (user == null) return;
    final normalized = code.trim().toUpperCase();
    for (var i = 0; i < _rooms.length; i++) {
      final room = _rooms[i];
      if (room.code == normalized && !room.members.contains(user.id)) {
        _rooms[i] = room.copyWith(members: [...room.members, user.id]);
        await _persist();
        notifyListeners();
        return;
      }
    }
  }

  Future<void> activateChallenge(String slug) async {
    _activeChallengeSlug = _slug(slug);
    await _persist();
    notifyListeners();
  }

  Future<void> activateCharityCampaign(String id) async {
    _activeCharityCampaignId = _slug(id);
    await _persist();
    notifyListeners();
  }

  List<UserModel> roomLeaderboard(String code) => _scopedLeaderboard(
      (entry) => entry.roomCode == code.trim().toUpperCase());

  CompetitionLeaders roomCompetition(String code) => _competition(
        (entry) => entry.roomCode == code.trim().toUpperCase(),
      );

  List<UserModel> challengeLeaderboard(String slug) {
    final normalized = _slug(slug);
    return _scopedLeaderboard((entry) => entry.challengeSlug == normalized);
  }

  CompetitionLeaders challengeCompetition(String slug) {
    final normalized = _slug(slug);
    return _competition((entry) => entry.challengeSlug == normalized);
  }

  List<UserModel> dailyLeaderboard(String date) =>
      _scopedLeaderboard((entry) => entry.dailyQuestionDate == date);

  List<UserModel> weeklyLeaderboard(String weekKey) {
    final normalized = _normalizeWeekKey(weekKey);
    if (normalized.isEmpty) return const [];
    return _scopedLeaderboard(
      (entry) =>
          _isoWeekKey(
            DateTime.fromMillisecondsSinceEpoch(entry.timestamp, isUtc: true),
          ) ==
          normalized,
    );
  }

  List<UserModel> _scopedLeaderboard(bool Function(HistoryEntry) include) {
    final users = _accounts.values
        .map((account) => account.user)
        .where((user) => user.history.any(include))
        .toList();
    users.sort((a, b) {
      int scopedTotal(UserModel user) => user.history
          .where(include)
          .fold(0, (sum, entry) => sum + entry.amountMinor);
      return scopedTotal(b).compareTo(scopedTotal(a));
    });
    return List.unmodifiable(users);
  }

  CompetitionLeaders _competition(bool Function(HistoryEntry) include) {
    final entries = <CompetitionEntry>[];
    for (final account in _accounts.values) {
      final user = account.user;
      final history = user.history.where(include).toList();
      if (history.isEmpty) continue;
      entries.add(
        CompetitionEntry(
          user: user,
          totalSpentMinor:
              history.fold(0, (sum, entry) => sum + entry.amountMinor),
          unlockedResultsCount: history.length,
          highestUnlockMinor:
              history.map((entry) => entry.amountMinor).reduce(max),
          ridiculousScore:
              history.map((entry) => entry.ridiculousScore).reduce(max),
          fastestRevealMs: _fastestRevealMs(history),
        ),
      );
    }

    int byName(CompetitionEntry a, CompetitionEntry b) =>
        a.username.compareTo(b.username);
    int firstNonZero(List<int> comparisons) {
      for (final comparison in comparisons) {
        if (comparison != 0) return comparison;
      }
      return 0;
    }

    final spent = [...entries]..sort((a, b) => firstNonZero([
          b.totalSpentMinor.compareTo(a.totalSpentMinor),
          b.unlockedResultsCount.compareTo(a.unlockedResultsCount),
          byName(a, b),
        ]));
    final highestUnlock = [...entries]..sort((a, b) => firstNonZero([
          b.highestUnlockMinor.compareTo(a.highestUnlockMinor),
          b.totalSpentMinor.compareTo(a.totalSpentMinor),
          byName(a, b),
        ]));
    final ridiculous = [...entries]..sort((a, b) => firstNonZero([
          b.ridiculousScore.compareTo(a.ridiculousScore),
          b.totalSpentMinor.compareTo(a.totalSpentMinor),
          byName(a, b),
        ]));
    final fastest =
        entries.where((entry) => entry.fastestRevealMs != null).toList()
          ..sort((a, b) => firstNonZero([
                a.fastestRevealMs!.compareTo(b.fastestRevealMs!),
                b.totalSpentMinor.compareTo(a.totalSpentMinor),
                byName(a, b),
              ]));

    return CompetitionLeaders(
      spent: List.unmodifiable(spent),
      highestUnlock: List.unmodifiable(highestUnlock),
      ridiculous: List.unmodifiable(ridiculous),
      fastest: List.unmodifiable(fastest),
    );
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

    _rooms
      ..clear()
      ..addAll(
        (jsonDecode(prefs.getString(_keyRooms) ?? '[]') as List)
            .whereType<Map>()
            .map((entry) => RichRoom.fromJson(entry.cast<String, dynamic>())),
      );
    _activeChallengeSlug = prefs.getString(_keyActiveChallenge);
    _activeCharityCampaignId = prefs.getString(_keyActiveCharity);

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
      reports +=
          user.profileComments.fold(0, (sum, c) => sum + c.reports.length);
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

  /// Heute lokal bereits ausgegebener Betrag fuer Resultat-Freischaltungen.
  int spentTodayMinor({DateTime? now}) {
    final user = currentUser;
    if (user == null) return 0;
    final day = now ?? DateTime.now();
    return user.history
        .where((entry) => _sameLocalDate(entry.timestamp, day))
        .fold(0, (sum, entry) => sum + entry.amountMinor);
  }

  bool canSpendToday(int amountMinor, {DateTime? now}) =>
      spentTodayMinor(now: now) + amountMinor <=
      PaymentConfig.dailySpendLimitMinor;

  /// Verbucht eine erfolgreiche (echte) Zahlung: erhöht den ausgegebenen Betrag
  /// und den Zähler (verdoppelt den nächsten Preis) und legt die freigeschaltete
  /// Rechnung im Verlauf ab (neueste zuerst, max. 50).
  Future<bool> recordPurchase({
    required int amountMinor,
    required String expression,
    required String result,
    String? roomCode,
    String? challengeSlug,
    String? dailyQuestionDate,
    String? charityCampaignId,
    int? durationMs,
    int? timestamp,
  }) async {
    final user = currentUser;
    if (user == null) return false;

    final now = DateTime.now();
    final purchaseTimestamp = timestamp ?? now.millisecondsSinceEpoch;
    final purchaseDay = DateTime.fromMillisecondsSinceEpoch(purchaseTimestamp);
    if (!canSpendToday(amountMinor, now: purchaseDay)) return false;

    user.totalSpentMinor += amountMinor;
    user.unlockedResultsCount += 1;
    if (amountMinor > user.highestUnlockMinor) {
      user.highestUnlockMinor = amountMinor;
    }
    final rank = leaderboardRankOf(user.id);
    user.history.insert(
      0,
      HistoryEntry(
        expression: expression,
        result: result,
        amountMinor: amountMinor,
        roomCode: roomCode?.trim().toUpperCase(),
        challengeSlug:
            challengeSlug == null ? _activeChallengeSlug : _slug(challengeSlug),
        dailyQuestionDate: dailyQuestionDate,
        charityCampaignId: charityCampaignId == null
            ? _activeCharityCampaignId
            : _slug(charityCampaignId),
        durationMs: _normalizeDurationMs(durationMs),
        rank: rank == 0 ? null : rank,
        timestamp: purchaseTimestamp,
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
    return true;
  }

  /// Löscht den Verlauf des aktuellen Benutzers.
  Future<void> clearHistory() async {
    final user = currentUser;
    if (user == null) return;
    user.history.clear();
    await _persist();
    notifyListeners();
  }

  bool _sameLocalDate(int timestamp, DateTime day) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return date.year == day.year &&
        date.month == day.month &&
        date.day == day.day;
  }

  int? _fastestRevealMs(List<HistoryEntry> entries) {
    final durations = entries
        .map((entry) => entry.durationMs)
        .whereType<int>()
        .where((duration) => duration > 0)
        .toList();
    if (durations.isEmpty) return null;
    return durations.reduce(min);
  }

  int? _normalizeDurationMs(int? durationMs) {
    if (durationMs == null || durationMs <= 0) return null;
    return min(durationMs, 86400000);
  }

  static final Random _idRandom = Random();

  /// Eindeutige Benutzer-ID – auch bei mehreren Registrierungen pro Millisekunde.
  String _generateUserId() =>
      '${DateTime.now().microsecondsSinceEpoch}_${_idRandom.nextInt(1 << 31)}';

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    final map = _accounts.map((k, v) => MapEntry(k, v.toJson()));
    await prefs.setString(_keyAccounts, jsonEncode(map));
    await prefs.setString(
      _keyRooms,
      jsonEncode(_rooms.map((room) => room.toJson()).toList()),
    );
    if (_activeChallengeSlug == null) {
      await prefs.remove(_keyActiveChallenge);
    } else {
      await prefs.setString(_keyActiveChallenge, _activeChallengeSlug!);
    }
    if (_activeCharityCampaignId == null) {
      await prefs.remove(_keyActiveCharity);
    } else {
      await prefs.setString(_keyActiveCharity, _activeCharityCampaignId!);
    }
    if (_currentEmail != null) {
      await prefs.setString(_keyCurrentEmail, _currentEmail!);
    }
  }

  String _roomCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    String code;
    do {
      code = List.generate(
        6,
        (_) => chars[_idRandom.nextInt(chars.length)],
      ).join();
    } while (_rooms.any((room) => room.code == code));
    return code;
  }

  String _slug(String value) => value
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');

  String _dateKey(DateTime value) => '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';

  String _normalizeWeekKey(String value) {
    final match = RegExp(r'^(\d{4})-W(\d{1,2})$', caseSensitive: false)
        .firstMatch(value.trim());
    if (match == null) return '';
    final week = int.tryParse(match.group(2)!);
    if (week == null || week < 1 || week > 53) return '';
    return '${match.group(1)}-W${week.toString().padLeft(2, '0')}';
  }

  String _isoWeekKey(DateTime value) {
    final utc = value.toUtc();
    final date = DateTime.utc(utc.year, utc.month, utc.day);
    final thursday = date.add(Duration(days: 4 - date.weekday));
    final yearStart = DateTime.utc(thursday.year, 1, 1);
    final week = ((thursday.difference(yearStart).inDays + 1) / 7).ceil();
    return '${thursday.year}-W${week.toString().padLeft(2, '0')}';
  }
}

class CompetitionLeaders {
  final List<CompetitionEntry> spent;
  final List<CompetitionEntry> highestUnlock;
  final List<CompetitionEntry> ridiculous;
  final List<CompetitionEntry> fastest;

  const CompetitionLeaders({
    required this.spent,
    required this.highestUnlock,
    required this.ridiculous,
    required this.fastest,
  });
}

class CompetitionEntry {
  final UserModel user;
  final int totalSpentMinor;
  final int unlockedResultsCount;
  final int highestUnlockMinor;
  final int ridiculousScore;
  final int? fastestRevealMs;

  const CompetitionEntry({
    required this.user,
    required this.totalSpentMinor,
    required this.unlockedResultsCount,
    required this.highestUnlockMinor,
    required this.ridiculousScore,
    required this.fastestRevealMs,
  });

  String get username => user.username;
  String get userId => user.id;
}

class DailyRichQuestion {
  final String date;
  final String title;
  final String expression;

  const DailyRichQuestion({
    required this.date,
    required this.title,
    required this.expression,
  });
}

class RichRoom {
  final String id;
  final String code;
  final String title;
  final String ownerId;
  final List<String> members;
  final int createdAt;

  const RichRoom({
    required this.id,
    required this.code,
    required this.title,
    required this.ownerId,
    required this.members,
    required this.createdAt,
  });

  RichRoom copyWith({List<String>? members}) => RichRoom(
        id: id,
        code: code,
        title: title,
        ownerId: ownerId,
        members: members ?? this.members,
        createdAt: createdAt,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'code': code,
        'title': title,
        'ownerId': ownerId,
        'members': members,
        'createdAt': createdAt,
      };

  factory RichRoom.fromJson(Map<String, dynamic> json) => RichRoom(
        id: json['id'] as String? ?? '',
        code: json['code'] as String? ?? '',
        title: json['title'] as String? ?? '',
        ownerId: json['ownerId'] as String? ?? '',
        members: (json['members'] as List?)?.whereType<String>().toList() ?? [],
        createdAt: json['createdAt'] as int? ?? 0,
      );
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
    final iterations = json['iterations'] as int? ?? _PasswordHasher.iterations;
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
