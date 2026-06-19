import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:calcoricher/gamification/achievements.dart';
import 'package:calcoricher/gamification/ranks.dart';
import 'package:calcoricher/main.dart';
import 'package:calcoricher/models/user_model.dart';
import 'package:calcoricher/payments/payment_config.dart';
import 'package:calcoricher/providers/user_provider.dart';

void main() {
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
    final commentId =
        provider.userById(adminId)!.profileComments.first.id;

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
    expect(await provider.login(email: 'bob@x.de', password: 'pass'),
        isNotNull);

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

    final ids = kAchievements
        .where((a) => a.isUnlocked(user))
        .map((a) => a.id)
        .toSet();
    expect(ids.containsAll({'first', 'rename', 'photo', 'plus'}), isTrue);
    expect(ids.contains('hundred'), isFalse);
  });

  testWidgets('App shows the splash and routes to login', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const RichCalculatorApp());
    await tester.pump();
    expect(find.text('CALCORICHER'), findsOneWidget);

    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(find.text('SIGN IN'), findsOneWidget);
  });
}
