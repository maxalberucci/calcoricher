import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:rich_calculator/main.dart';
import 'package:rich_calculator/models/user_model.dart';
import 'package:rich_calculator/payments/payment_config.dart';
import 'package:rich_calculator/providers/user_provider.dart';

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

  testWidgets('App zeigt den Splash und routet zum Login', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const RichCalculatorApp());
    await tester.pump();
    expect(find.text('DER REICHEN-\nRECHNER'), findsOneWidget);

    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(find.text('ANMELDEN'), findsOneWidget);
  });
}
