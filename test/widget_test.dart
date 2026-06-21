import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:calcoricher/gamification/achievements.dart';
import 'package:calcoricher/gamification/ranks.dart';
import 'package:calcoricher/legal/legal_meta.dart';
import 'package:calcoricher/main.dart';
import 'package:calcoricher/models/user_model.dart';
import 'package:calcoricher/payments/payment_config.dart';
import 'package:calcoricher/providers/user_provider.dart';
import 'package:calcoricher/utils/url_safety.dart';

void main() {
  group('Sicherheit', () {
    test('UrlSafety lässt nur sichere http(s)-Links zu', () {
      // Schemalose Eingabe -> https.
      expect(UrlSafety.normalize('example.com'), 'https://example.com');
      expect(UrlSafety.normalize('  example.com/x  '), 'https://example.com/x');
      expect(UrlSafety.normalize('http://a.com'), 'http://a.com');

      // Gefährliche/ungültige Schemata werden abgewiesen.
      expect(UrlSafety.normalize('javascript:alert(1)'), isNull);
      expect(UrlSafety.normalize('file:///etc/passwd'), isNull);
      expect(UrlSafety.normalize('tel:+411234'), isNull);
      expect(UrlSafety.normalize('mailto:a@b.com'), isNull);
      expect(UrlSafety.normalize(''), isNull);
      expect(UrlSafety.normalize('https://'), isNull);

      // isSafeWebUri prüft das Schema unmittelbar vor dem Öffnen.
      expect(UrlSafety.isSafeWebUri(Uri.parse('https://a.com')), isTrue);
      expect(UrlSafety.isSafeWebUri(Uri.parse('javascript:x')), isFalse);
      expect(UrlSafety.isSafeWebUri(Uri.parse('file:///x')), isFalse);
    });

    test('Profil-Links werden serverseitig auf sichere Links gefiltert',
        () async {
      SharedPreferences.setMockInitialValues({});
      final provider = UserProvider();
      await provider.init();
      await provider.register(
          username: 'Max', email: 'max@reich.de', password: 'geld');

      await provider.updateProfileDetails(links: [
        'javascript:alert(1)', // gefährlich -> raus
        'file:///etc/passwd', // gefährlich -> raus
        'good.com', // -> https://good.com
        'https://safe.com',
      ]);

      final links = provider.currentUser!.links;
      expect(links, containsAll(['https://good.com', 'https://safe.com']));
      expect(links.any((l) => l.startsWith('javascript')), isFalse);
      expect(links.any((l) => l.startsWith('file')), isFalse);
    });

    test('Überlange Eingaben werden begrenzt', () async {
      SharedPreferences.setMockInitialValues({});
      final provider = UserProvider();
      await provider.init();
      await provider.register(
          username: 'A' * 500, email: 'max@reich.de', password: 'geld');

      expect(provider.currentUser!.username.length, lessThanOrEqualTo(80));

      await provider.updateProfileDetails(bio: 'x' * 5000);
      expect(provider.currentUser!.bio.length, lessThanOrEqualTo(1000));
    });

    test('Passwörter werden als PBKDF2-Hash gespeichert (kein Klartext)',
        () async {
      SharedPreferences.setMockInitialValues({});
      final provider = UserProvider();
      await provider.init();
      await provider.register(
          username: 'Max', email: 'max@reich.de', password: 'supersecret');

      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('accounts_v2')!;
      // Klartext-Passwort darf nirgends im Storage auftauchen.
      expect(raw.contains('supersecret'), isFalse);
      expect(raw.contains('pbkdf2'), isTrue);

      // Falsches Passwort scheitert, richtiges gelingt.
      await provider.logout();
      expect(await provider.login(email: 'max@reich.de', password: 'wrong'),
          isNotNull);
      expect(
          await provider.login(email: 'max@reich.de', password: 'supersecret'),
          isNull);
    });

    test('Alt-Konten (Klartext-Schema) werden beim Login auf PBKDF2 migriert',
        () async {
      // Konto im ALTEN Schema: nur ein Klartext-Passwort, kein Hash/Algo.
      SharedPreferences.setMockInitialValues({
        'accounts_v2': '{"old@x.de":{"password":"plain123",'
            '"user":{"id":"u1","username":"Old","email":"old@x.de"}}}',
      });

      final provider = UserProvider();
      await provider.init();

      // Falsches Passwort scheitert, richtiges (Klartext-Migration) gelingt.
      expect(
          await provider.login(email: 'old@x.de', password: 'nope'), isNotNull);
      expect(await provider.login(email: 'old@x.de', password: 'plain123'),
          isNull);

      // Nach dem Login ist das Konto auf PBKDF2 angehoben (kein Klartext mehr).
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('accounts_v2')!;
      expect(raw.contains('plain123'), isFalse);
      expect(raw.contains('pbkdf2'), isTrue);
    });
  });

  test('Preis verdoppelt sich pro freigeschaltetem Resultat', () {
    final user = UserModel(id: '1', username: 'Test', email: 't@t.de');
    const base = PaymentConfig.basePriceMinor;
    expect(user.currentPriceMultiplier, 1);
    expect(user.currentResultPriceMinor, base);
    user.unlockedResultsCount = 1;
    expect(user.currentResultPriceMinor, base * 2);
    user.unlockedResultsCount = 2;
    expect(user.currentResultPriceMinor, base * 4);
    user.unlockedResultsCount = 6;
    expect(user.currentResultPriceMinor, base * 64);
  });

  test('Startwerte sind korrekt', () {
    final user = UserModel(id: '1', username: 'Test', email: 't@t.de');
    expect(user.totalSpentMinor, 0);
    expect(user.unlockedResultsCount, 0);
    expect(user.currentResultPriceMinor, PaymentConfig.basePriceMinor);
  });

  test('format() stellt Minor-Units korrekt dar', () {
    expect(PaymentConfig.format(100), '${PaymentConfig.currencySymbol} 1.00');
    expect(PaymentConfig.format(250), '${PaymentConfig.currencySymbol} 2.50');
    expect(PaymentConfig.format(5), '${PaymentConfig.currencySymbol} 0.05');
  });

  test('Registrierung, Login, Kauf und Logout funktionieren', () async {
    SharedPreferences.setMockInitialValues({});
    final provider = UserProvider();
    await provider.init();

    final err = await provider.register(
      username: 'Max',
      email: 'max@reich.de',
      password: 'geld',
    );
    expect(err, isNull);
    expect(provider.hasUser, isTrue);
    expect(provider.currentUser?.totalSpentMinor, 0);

    // Kauf verbuchen -> Betrag & Zähler steigen, Preis verdoppelt sich,
    // Verlauf-Eintrag wird angelegt.
    final price = provider.currentUser!.currentResultPriceMinor;
    await provider.recordPurchase(
        amountMinor: price, expression: '2 + 2', result: '4');
    expect(provider.currentUser?.totalSpentMinor, price);
    expect(provider.currentUser?.unlockedResultsCount, 1);
    expect(provider.currentUser?.currentResultPriceMinor, price * 2);
    expect(provider.currentUser?.history.length, 1);
    expect(provider.currentUser?.history.first.result, '4');

    await provider.clearHistory();
    expect(provider.currentUser?.history, isEmpty);

    // Namensänderung kostet Geld (zählt zum ausgegebenen Betrag, nicht zum
    // Resultat-Zähler).
    final spentBefore = provider.currentUser!.totalSpentMinor;
    final unlockedBefore = provider.currentUser!.unlockedResultsCount;
    await provider.changeUsername('Crassus', 100000);
    expect(provider.currentUser?.username, 'Crassus');
    expect(provider.currentUser?.totalSpentMinor, spentBefore + 100000);
    expect(provider.currentUser?.unlockedResultsCount, unlockedBefore);

    await provider.logout();
    expect(provider.hasUser, isFalse);

    final loginErr =
        await provider.login(email: 'max@reich.de', password: 'geld');
    expect(loginErr, isNull);
    expect(provider.hasUser, isTrue);

    final wrong =
        await provider.login(email: 'max@reich.de', password: 'falsch');
    expect(wrong, isNotNull);
  });

  test('Tageslimit verhindert weitere Käufe im lokalen Sandbox-Modus',
      () async {
    SharedPreferences.setMockInitialValues({});
    final provider = UserProvider();
    await provider.init();
    await provider.register(
      username: 'Limit',
      email: 'limit@x.de',
      password: 'pass',
    );

    final first = await provider.recordPurchase(
      amountMinor: PaymentConfig.dailySpendLimitMinor - 100,
      expression: '1 + 1',
      result: '2',
    );
    expect(first, isTrue);

    final blocked = await provider.recordPurchase(
      amountMinor: 200,
      expression: '2 + 2',
      result: '4',
    );
    expect(blocked, isFalse);
    expect(
      provider.currentUser!.totalSpentMinor,
      PaymentConfig.dailySpendLimitMinor - 100,
    );
  });

  test('Produkt-Loop erzeugt Feed, Räume, Challenges, Charity und Receipts',
      () async {
    SharedPreferences.setMockInitialValues({});
    final provider = UserProvider();
    await provider.init();
    await provider.register(
      username: 'Ada',
      email: 'ada@rich.test',
      password: 'pass',
    );

    final daily = provider.dailyRichQuestion;
    expect(daily.title, 'Daily Rich Question');
    expect(daily.expression, isNotEmpty);

    final room = await provider.createRoom(title: 'Sunday Rich Room');
    await provider.activateChallenge('streamer-night');
    await provider.activateCharityCampaign('math-relief');

    final recorded = await provider.recordPurchase(
      amountMinor: 400,
      expression: '17 * 3',
      result: '51',
      roomCode: room.code,
      challengeSlug: 'streamer-night',
      dailyQuestionDate: daily.date,
      charityCampaignId: 'math-relief',
    );
    expect(recorded, isTrue);

    final feed = provider.publicFeed;
    expect(feed.first.by, 'Ada');
    expect(feed.first.expression, '17 * 3');
    expect(feed.first.shareText, 'I paid CHF 4.00 for this answer.');
    expect(feed.first.roomCode, room.code);
    expect(feed.first.challengeSlug, 'streamer-night');
    expect(feed.first.charityCampaignId, 'math-relief');

    expect(provider.roomLeaderboard(room.code).first.username, 'Ada');
    expect(
        provider.challengeLeaderboard('streamer-night').first.username, 'Ada');
    expect(provider.dailyLeaderboard(daily.date).first.username, 'Ada');
    expect(provider.currentUser!.receiptGallery.first.shareText,
        'I paid CHF 4.00 for this answer.');
    expect(provider.currentUser!.receiptGallery.first.rank, 1);
    expect(provider.currentUser!.flexTitles, contains('Receipt Collector'));
  });

  test('Produkt-Loop rangiert Raum- und Challenge-Wettbewerbe nach Kategorien',
      () async {
    SharedPreferences.setMockInitialValues({});
    final provider = UserProvider();
    await provider.init();
    await provider.register(
      username: 'Ada',
      email: 'ada@rich.test',
      password: 'pass',
    );
    final room = await provider.createRoom(title: 'Ridiculous Math Room');
    await provider.activateChallenge('streamer-night');
    await provider.recordPurchase(
      amountMinor: 900,
      expression: '999999999 * (888888 + 7777) / 3 - 1',
      result: '299999666370',
      roomCode: room.code,
      challengeSlug: 'streamer-night',
      durationMs: 8200,
    );

    await provider.register(
      username: 'Bob',
      email: 'bob@rich.test',
      password: 'pass',
    );
    await provider.recordPurchase(
      amountMinor: 500,
      expression: '2 + 2',
      result: '4',
      roomCode: room.code,
      challengeSlug: 'streamer-night',
      durationMs: 1100,
    );
    await provider.recordPurchase(
      amountMinor: 500,
      expression: '3 + 3',
      result: '6',
      roomCode: room.code,
      challengeSlug: 'streamer-night',
      durationMs: 1300,
    );

    final roomCompetition = provider.roomCompetition(room.code);
    expect(roomCompetition.spent.first.username, 'Bob');
    expect(roomCompetition.highestUnlock.first.username, 'Ada');
    expect(roomCompetition.ridiculous.first.username, 'Ada');
    expect(roomCompetition.fastest.first.username, 'Bob');
    expect(roomCompetition.fastest.first.fastestRevealMs, 1100);

    final challengeCompetition =
        provider.challengeCompetition('streamer-night');
    expect(challengeCompetition.spent.first.username, 'Bob');
    expect(challengeCompetition.highestUnlock.first.username, 'Ada');
    expect(challengeCompetition.ridiculous.first.username, 'Ada');
    expect(challengeCompetition.fastest.first.username, 'Bob');
  });

  test('Woechentliche Rangliste setzt an ISO-Wochengrenzen zurueck', () async {
    SharedPreferences.setMockInitialValues({});
    final provider = UserProvider();
    await provider.init();
    await provider.register(
      username: 'Ada',
      email: 'ada@rich.test',
      password: 'pass',
    );
    await provider.recordPurchase(
      amountMinor: 700,
      expression: '10 + 1',
      result: '11',
      timestamp: DateTime.utc(2026, 6, 21, 12).millisecondsSinceEpoch,
    );
    await provider.register(
      username: 'Bob',
      email: 'bob@rich.test',
      password: 'pass',
    );
    await provider.recordPurchase(
      amountMinor: 800,
      expression: '10 + 2',
      result: '12',
      timestamp: DateTime.utc(2026, 6, 22, 12).millisecondsSinceEpoch,
    );

    expect(provider.weeklyLeaderboard('2026-W25').single.username, 'Ada');
    expect(provider.weeklyLeaderboard('2026-W26').single.username, 'Bob');
  });

  test('Profile flex unlocks rare frames from expensive receipts', () async {
    SharedPreferences.setMockInitialValues({});
    final provider = UserProvider();
    await provider.init();
    await provider.register(
      username: 'Ada',
      email: 'ada@rich.test',
      password: 'pass',
    );
    await provider.recordPurchase(
      amountMinor: PaymentConfig.dailySpendLimitMinor,
      expression: '999 * 999',
      result: '998001',
    );

    expect(provider.currentUser!.luxuryFrame.name, 'Diamond Frame');
    expect(provider.currentUser!.luxuryFrame.rarity, 'Rare');
    expect(provider.currentUser!.flexTitles, contains('Diamond Frame'));
  });

  test('Reporting und Admin-Tool funktionieren', () async {
    SharedPreferences.setMockInitialValues({});
    final provider = UserProvider();
    await provider.init();

    // Admin-Konto (E-Mail aus AdminConfig) + zwei normale Nutzer.
    await provider.register(
        username: 'Admin', email: 'max.alberucci@gmail.com', password: 'pass');
    final adminId = provider.currentUser!.id;
    expect(provider.isAdmin, isTrue);

    await provider.register(
        username: 'Bob', email: 'bob@x.de', password: 'pass');
    expect(provider.isAdmin, isFalse);
    // Bob kommentiert das Admin-Profil.
    await provider.addProfileComment(targetUserId: adminId, text: 'rude');
    final commentId = provider.userById(adminId)!.profileComments.first.id;

    await provider.register(
        username: 'Cara', email: 'cara@x.de', password: 'pass');
    // Cara meldet den Kommentar (neu -> true, doppelt -> false).
    expect(
      await provider.reportProfileComment(
          targetUserId: adminId, commentId: commentId, reason: 'Spam'),
      isTrue,
    );
    expect(
      await provider.reportProfileComment(
          targetUserId: adminId, commentId: commentId, reason: 'Spam'),
      isFalse,
    );
    expect(provider.reportedComments.length, 1);

    // Nicht-Admin (Cara) darf nicht löschen -> Kommentar bleibt.
    await provider.adminDeleteComment(
        targetUserId: adminId, commentId: commentId);
    expect(provider.userById(adminId)!.profileComments.length, 1);

    // Admin sieht die Meldung und kann sie verwerfen.
    await provider.login(email: 'max.alberucci@gmail.com', password: 'pass');
    expect(provider.reportedCommentCount, 1);
    await provider.adminDismissReports(
        targetUserId: adminId, commentId: commentId);
    expect(provider.reportedComments, isEmpty);
    expect(provider.userById(adminId)!.profileComments.length, 1);

    // Erneut melden, dann als Admin löschen -> Kommentar verschwindet.
    await provider.login(email: 'cara@x.de', password: 'pass');
    await provider.reportProfileComment(
        targetUserId: adminId, commentId: commentId, reason: 'Harassment');
    await provider.login(email: 'max.alberucci@gmail.com', password: 'pass');
    await provider.adminDeleteComment(
        targetUserId: adminId, commentId: commentId);
    expect(provider.userById(adminId)!.profileComments, isEmpty);
    expect(provider.reportedComments, isEmpty);
  });

  test('Admin kann Nutzer bannen und Statistiken stimmen', () async {
    SharedPreferences.setMockInitialValues({});
    final provider = UserProvider();
    await provider.init();

    await provider.register(
        username: 'Admin', email: 'max.alberucci@gmail.com', password: 'pass');
    await provider.register(
        username: 'Bob', email: 'bob@x.de', password: 'pass');
    final bobId = provider.currentUser!.id;
    await provider.register(
        username: 'Cara', email: 'cara@x.de', password: 'pass');

    // Cara (kein Admin) kann nicht bannen.
    await provider.adminSetBanned(userId: bobId, banned: true);
    expect(provider.userById(bobId)!.isBanned, isFalse);

    // Admin bannt Bob -> Login schlägt fehl.
    await provider.login(email: 'max.alberucci@gmail.com', password: 'pass');
    await provider.adminSetBanned(userId: bobId, banned: true);
    expect(provider.userById(bobId)!.isBanned, isTrue);
    expect(
        await provider.login(email: 'bob@x.de', password: 'pass'), isNotNull);

    // Admins selbst können nicht gebannt werden.
    await provider.login(email: 'max.alberucci@gmail.com', password: 'pass');
    final adminId = provider.currentUser!.id;
    await provider.adminSetBanned(userId: adminId, banned: true);
    expect(provider.userById(adminId)!.isBanned, isFalse);

    final stats = provider.adminStats;
    expect(stats.users, 3);
    expect(stats.banned, 1);

    // Entbannen erlaubt Login wieder.
    await provider.adminSetBanned(userId: bobId, banned: false);
    expect(await provider.login(email: 'bob@x.de', password: 'pass'), isNull);
  });

  test('Rang richtet sich nach ausgegebenem Geld', () {
    expect(rankForSpent(0).name, 'Pauper');
    expect(rankForSpent(10000).name, 'Patron'); //   100.00
    expect(rankForSpent(100000).name, 'Magnate'); // 1000.00
    expect(rankForSpent(999999999).name, 'Croesus');
    expect(rankProgress(999999999), 1.0); // Maximalrang
  });

  test('Achievements schalten anhand des Zustands frei', () {
    final user = UserModel(id: '1', username: 'Test', email: 't@t.de');
    expect(unlockedCount(user), 0);

    user.unlockedResultsCount = 1;
    user.usernameChanges = 1;
    user.avatarPath = '/some/path.png';
    user.operatorCounts['+'] = 10;

    final ids =
        kAchievements.where((a) => a.isUnlocked(user)).map((a) => a.id).toSet();
    expect(ids.containsAll({'first', 'rename', 'photo', 'plus'}), isTrue);
    expect(ids.contains('hundred'), isFalse);
  });

  testWidgets('App shows the splash and routes to login', (tester) async {
    SharedPreferences.setMockInitialValues(_withConsent());
    await tester.pumpWidget(const RichCalculatorApp());
    await tester.pump();
    expect(find.text('CALCORICHER'), findsOneWidget);

    await _finishSplash(tester);
    expect(find.text('Calculator'), findsOneWidget);
    expect(find.text('Social'), findsOneWidget);
    expect(find.text('SIGN IN'), findsNothing);
    expect(find.textContaining('Calculate first'), findsOneWidget);
  });

  testWidgets(
      'Social tab exposes feed, daily, rooms, creator, charity and guardrails',
      (tester) async {
    SharedPreferences.setMockInitialValues(_withConsent());
    await tester.pumpWidget(const RichCalculatorApp());
    await _finishSplash(tester);

    await tester.tap(find.text('Social'));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('DAILY RICH QUESTION'), findsOneWidget);
    expect(find.text('RECENTLY UNLOCKED'), findsOneWidget);
    expect(find.text('PRIVATE ROOMS'), findsOneWidget);
    expect(find.text('CREATOR MODE'), findsOneWidget);
    expect(find.text('CHARITY MODE'), findsOneWidget);
    expect(find.text('SPENDING GUARDRAILS'), findsOneWidget);
    expect(find.textContaining('This is satire'), findsOneWidget);
  });

  testWidgets('Social room cards show competition leaders', (tester) async {
    SharedPreferences.setMockInitialValues(_withConsent());
    final provider = UserProvider();
    await provider.init();
    await provider.register(
      username: 'Ada',
      email: 'ada@rich.test',
      password: 'pass',
    );
    final room = await provider.createRoom(title: 'Ridiculous Math Room');
    await provider.recordPurchase(
      amountMinor: 900,
      expression: '999999999 * (888888 + 7777) / 3 - 1',
      result: '299999666370',
      roomCode: room.code,
      durationMs: 8200,
    );
    await provider.register(
      username: 'Bob',
      email: 'bob@rich.test',
      password: 'pass',
    );
    await provider.recordPurchase(
      amountMinor: 500,
      expression: '2 + 2',
      result: '4',
      roomCode: room.code,
      durationMs: 1100,
    );
    await provider.recordPurchase(
      amountMinor: 500,
      expression: '3 + 3',
      result: '6',
      roomCode: room.code,
      durationMs: 1300,
    );

    await tester.pumpWidget(const RichCalculatorApp());
    await _finishSplash(tester);

    await tester.tap(find.text('Social'));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.textContaining('Spend: Bob'), findsOneWidget);
    expect(find.textContaining('Highest unlock: Ada'), findsOneWidget);
    expect(find.textContaining('Most ridiculous: Ada'), findsOneWidget);
    expect(find.textContaining('Fastest reveal: Bob'), findsOneWidget);
  });

  testWidgets('Profile shows receipt gallery and flex titles', (tester) async {
    SharedPreferences.setMockInitialValues(_withConsent());
    final provider = UserProvider();
    await provider.init();
    await provider.register(
      username: 'Ada',
      email: 'ada@rich.test',
      password: 'pass',
    );
    await provider.recordPurchase(
      amountMinor: 400,
      expression: '17 * 3',
      result: '51',
    );

    await tester.pumpWidget(const RichCalculatorApp());
    await _finishSplash(tester);

    await tester.tap(find.text('Profile'));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('RECEIPT GALLERY'), findsOneWidget);
    expect(
        find.textContaining('I paid CHF 4.00 for this answer'), findsOneWidget);
    expect(find.text('Rank #1'), findsOneWidget);
    expect(find.text('Receipt Collector'), findsOneWidget);
  });

  testWidgets('Profile shows rare frame and animated receipt cards',
      (tester) async {
    SharedPreferences.setMockInitialValues(_withConsent());
    final provider = UserProvider();
    await provider.init();
    await provider.register(
      username: 'Ada',
      email: 'ada@rich.test',
      password: 'pass',
    );
    await provider.recordPurchase(
      amountMinor: PaymentConfig.dailySpendLimitMinor,
      expression: '999 * 999',
      result: '998001',
    );

    await tester.pumpWidget(const RichCalculatorApp());
    await _finishSplash(tester);

    await tester.tap(find.text('Profile'));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Diamond Frame'), findsWidgets);
    expect(find.text('Rare'), findsOneWidget);
    expect(find.byType(TweenAnimationBuilder<double>), findsWidgets);
  });

  testWidgets('Guest can calculate before sign-in and is gated only at reveal',
      (tester) async {
    SharedPreferences.setMockInitialValues(_withConsent());
    await tester.pumpWidget(const RichCalculatorApp());
    await _finishSplash(tester);

    await tester.tap(find.text('1'));
    await tester.tap(find.text('+'));
    await tester.tap(find.text('1'));
    await tester.tap(find.text('='));
    await tester.pump();

    expect(find.text('SIGN IN TO UNLOCK'), findsOneWidget);
    expect(find.text('SIGN IN'), findsNothing);

    await tester.tap(find.text('SIGN IN TO UNLOCK'));
    await tester.pumpAndSettle();
    expect(find.text('SIGN IN'), findsOneWidget);
  });

  testWidgets('Saved admin session routes to the admin interface',
      (tester) async {
    SharedPreferences.setMockInitialValues(_withConsent());
    final provider = UserProvider();
    await provider.init();
    await provider.register(
      username: 'Admin',
      email: 'max.alberucci@gmail.com',
      password: 'pass',
    );

    await tester.pumpWidget(const RichCalculatorApp());
    await _finishSplash(tester);

    expect(find.text('ADMIN'), findsOneWidget);
    expect(find.text('OVERVIEW'), findsOneWidget);
    expect(find.text('Calculator'), findsNothing);
  });

  testWidgets('Admin can search users and open user details', (tester) async {
    SharedPreferences.setMockInitialValues(_withConsent());
    final provider = UserProvider();
    await provider.init();
    await provider.register(
      username: 'Admin',
      email: 'max.alberucci@gmail.com',
      password: 'pass',
    );
    await provider.register(
        username: 'Bob', email: 'bob@x.de', password: 'pass');
    await provider.recordPurchase(
      amountMinor: PaymentConfig.basePriceMinor,
      expression: '2 + 2',
      result: '4',
    );
    await provider.register(
      username: 'Cara',
      email: 'cara@x.de',
      password: 'pass',
    );
    await provider.login(email: 'max.alberucci@gmail.com', password: 'pass');

    await tester.pumpWidget(const RichCalculatorApp());
    await _finishSplash(tester);

    await tester.tap(find.widgetWithText(Tab, 'USERS'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('admin-user-search')),
      'bob',
    );
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Bob'), findsOneWidget);
    expect(find.text('Cara'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('admin-user-row-bob@x.de')));
    await tester.pumpAndSettle();

    expect(find.text('USER DETAILS'), findsOneWidget);
    expect(find.text('bob@x.de'), findsOneWidget);
    expect(find.text('BAN USER'), findsOneWidget);
    expect(find.text('ACCOUNT STATS'), findsOneWidget);
  });
}

Map<String, Object> _withConsent([Map<String, Object> values = const {}]) => {
      'legal_consent_version': LegalMeta.consentVersion,
      ...values,
    };

Future<void> _finishSplash(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 2600));
  await tester.pump(const Duration(milliseconds: 700));
}
