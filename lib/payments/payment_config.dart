/// Zentrale Zahlungs-Konfiguration.
///
/// ▸ Solange [sandbox] true ist, läuft die App ohne Backend/Keys und simuliert
///   Zahlungen (ideal zum Entwickeln & auf dem Desktop).
/// ▸ Für ECHTE Zahlungen: [sandbox] = false setzen und [backendBaseUrl] auf
///   deinen Stripe-Backend-Endpoint zeigen lassen (siehe server/README.md).
///   Der geheime Stripe-Key lebt NUR im Backend, niemals in dieser App.
class PaymentConfig {
  PaymentConfig._();

  // --- Hier anpassen -------------------------------------------------------

  /// Sandbox = Zahlungen werden simuliert (kein echtes Geld, kein Backend).
  static const bool sandbox = true;

  /// Basis dieses URL: dein Stripe-Backend (z. B. https://api.deinedomain.ch).
  static const String backendBaseUrl = 'https://example.com';

  /// Optionaler gehosteter Krypto-Checkout (Coinbase Commerce / NOWPayments).
  /// Leer lassen, um die Krypto-Option auszublenden.
  static const String cryptoCheckoutUrl = '';

  /// Währung. [currencyCode] muss ein gültiger Stripe-Code sein (z. B. chf, eur, usd).
  static const String currencyCode = 'chf';
  static const String currencySymbol = 'CHF';

  /// Basispreis in Minor-Units (Rappen/Cent). 100 = 1.00.
  /// Das erste Resultat kostet diesen Betrag, danach verdoppelt er sich.
  static const int basePriceMinor = 100;

  /// Lokales Tageslimit in Minor-Units. Das Backend erzwingt denselben Schutz
  /// global; dieser Wert schuetzt auch Sandbox- und Offline-Demos.
  static const int dailySpendLimitMinor = 10000;

  static const String satireDisclosure =
      'This is satire. You are paying to reveal a calculated result for entertainment.';
  static const String refundUrl = 'mailto:refunds@example.com';
  static const String helpUrl = 'mailto:support@example.com';

  /// Preis für eine Änderung des Benutzernamens in Minor-Units.
  /// 100000 = 1000.00 (Eitelkeit ist teuer).
  static const int usernameChangePriceMinor = 100000;

  // -------------------------------------------------------------------------

  /// Formatiert Minor-Units als lesbaren Preis, z. B. 250 -> "CHF 2.50".
  static String format(int minor) {
    final whole = minor ~/ 100;
    final cents = (minor % 100).toString().padLeft(2, '0');
    return '$currencySymbol $whole.$cents';
  }
}
