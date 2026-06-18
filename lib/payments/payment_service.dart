import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'payment_config.dart';

enum PaymentStatus { success, cancelled, failed }

class PaymentResult {
  final PaymentStatus status;
  final String? message;

  const PaymentResult(this.status, [this.message]);

  bool get isSuccess => status == PaymentStatus.success;

  static const success = PaymentResult(PaymentStatus.success);
  static const cancelled = PaymentResult(PaymentStatus.cancelled);
}

/// Abstraktion über die konkrete Bezahlmethode, damit die UI nichts über
/// Stripe/Sandbox wissen muss.
abstract class PaymentService {
  /// Belastet [amountMinor] (Minor-Units) für ein Resultat.
  Future<PaymentResult> payForResult({
    required int amountMinor,
    required String description,
  });

  /// Optionaler Krypto-Checkout (öffnet gehostete Seite). null = nicht verfügbar.
  Future<PaymentResult>? payWithCrypto({
    required int amountMinor,
    required String description,
  });

  /// Wählt anhand der Konfiguration die passende Implementierung.
  factory PaymentService.create() => PaymentConfig.sandbox
      ? SandboxPaymentService()
      : StripeCheckoutService();
}

/// Echte Zahlungen über Stripe Checkout (Karte · Apple Pay · Google Pay).
///
/// Ablauf: Backend erstellt eine Checkout-Session (mit dem geheimen Key),
/// liefert eine URL zurück; die App öffnet sie im Browser und fragt danach
/// den Bezahlstatus beim Backend ab.
class StripeCheckoutService implements PaymentService {
  final http.Client _client;
  StripeCheckoutService([http.Client? client])
      : _client = client ?? http.Client();

  @override
  Future<PaymentResult> payForResult({
    required int amountMinor,
    required String description,
  }) async {
    try {
      // 1) Checkout-Session vom Backend anfordern.
      final createRes = await _client.post(
        Uri.parse('${PaymentConfig.backendBaseUrl}/create-checkout-session'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'amount': amountMinor,
          'currency': PaymentConfig.currencyCode,
          'description': description,
        }),
      );
      if (createRes.statusCode != 200) {
        return PaymentResult(
            PaymentStatus.failed, 'Server error (${createRes.statusCode}).');
      }
      final data = jsonDecode(createRes.body) as Map<String, dynamic>;
      final sessionId = data['id'] as String;
      final url = data['url'] as String;

      // 2) Hosted Checkout öffnen (dort wählt der Nutzer Karte/Wallet).
      final launched = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
      if (!launched) {
        return const PaymentResult(
            PaymentStatus.failed, 'Could not open checkout.');
      }

      // 3) Bezahlstatus pollen (max. ~3 Minuten).
      return _pollStatus(sessionId);
    } catch (e) {
      return PaymentResult(PaymentStatus.failed, 'Network error: $e');
    }
  }

  Future<PaymentResult> _pollStatus(String sessionId) async {
    const interval = Duration(seconds: 2);
    const maxTries = 90;
    for (var i = 0; i < maxTries; i++) {
      await Future.delayed(interval);
      final res = await _client.get(
        Uri.parse(
            '${PaymentConfig.backendBaseUrl}/session-status?id=$sessionId'),
      );
      if (res.statusCode != 200) continue;
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final status = data['status'] as String?;
      if (status == 'paid') return PaymentResult.success;
      if (status == 'expired' || status == 'canceled') {
        return PaymentResult.cancelled;
      }
    }
    return const PaymentResult(
        PaymentStatus.failed, 'Timed out waiting for confirmation.');
  }

  @override
  Future<PaymentResult>? payWithCrypto({
    required int amountMinor,
    required String description,
  }) {
    if (PaymentConfig.cryptoCheckoutUrl.isEmpty) return null;
    return _openCrypto();
  }

  Future<PaymentResult> _openCrypto() async {
    final ok = await launchUrl(
      Uri.parse(PaymentConfig.cryptoCheckoutUrl),
      mode: LaunchMode.externalApplication,
    );
    // Bei externem Hosted-Crypto-Checkout kann der Client den Abschluss nicht
    // sicher verifizieren – hier müsste in Produktion ein Webhook greifen.
    return ok
        ? const PaymentResult(PaymentStatus.failed,
            'Crypto payment is confirmed via webhook.')
        : const PaymentResult(
            PaymentStatus.failed, 'Could not open crypto checkout.');
  }
}

/// Simuliert Zahlungen ohne Backend/echtes Geld (Entwicklung & Desktop-Demo).
class SandboxPaymentService implements PaymentService {
  @override
  Future<PaymentResult> payForResult({
    required int amountMinor,
    required String description,
  }) async {
    await Future.delayed(const Duration(milliseconds: 1600));
    return PaymentResult.success;
  }

  @override
  Future<PaymentResult>? payWithCrypto({
    required int amountMinor,
    required String description,
  }) async {
    await Future.delayed(const Duration(milliseconds: 1600));
    return PaymentResult.success;
  }
}
