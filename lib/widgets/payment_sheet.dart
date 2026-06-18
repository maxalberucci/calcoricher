import 'package:flutter/material.dart';
import '../payments/payment_config.dart';
import '../payments/payment_service.dart';
import '../theme/app_theme.dart';

/// Öffnet das Bezahl-Sheet und gibt `true` zurück, wenn die Zahlung erfolgreich war.
Future<bool> showPaymentSheet(
  BuildContext context, {
  required int amountMinor,
  required String description,
}) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) =>
        _PaymentSheet(amountMinor: amountMinor, description: description),
  );
  return result ?? false;
}

class _PaymentSheet extends StatefulWidget {
  final int amountMinor;
  final String description;

  const _PaymentSheet({required this.amountMinor, required this.description});

  @override
  State<_PaymentSheet> createState() => _PaymentSheetState();
}

class _PaymentSheetState extends State<_PaymentSheet> {
  final PaymentService _service = PaymentService.create();
  bool _processing = false;
  String? _error;

  Future<void> _run(Future<PaymentResult>? future) async {
    if (future == null || _processing) return;
    setState(() {
      _processing = true;
      _error = null;
    });

    final result = await future;
    if (!mounted) return;

    if (result.isSuccess) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _processing = false;
      _error = result.status == PaymentStatus.cancelled
          ? 'Zahlung abgebrochen.'
          : (result.message ?? 'Zahlung fehlgeschlagen.');
    });
  }

  @override
  Widget build(BuildContext context) {
    final cryptoFuture = _service.payWithCrypto(
      amountMinor: widget.amountMinor,
      description: widget.description,
    );

    return Container(
      padding: EdgeInsets.fromLTRB(
        24,
        14,
        24,
        24 + MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppTheme.cardHigh, AppTheme.surface],
        ),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(top: BorderSide(color: AppTheme.gold, width: 1)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'RESULTAT FREISCHALTEN',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 11,
              letterSpacing: 2,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            PaymentConfig.format(widget.amountMinor),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppTheme.gold,
              fontSize: 44,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'für „${widget.description}"',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 13,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 22),

          // Unterstützte Methoden (laufen über Stripe Checkout).
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _MethodBadge(icon: Icons.apple, label: 'Apple Pay'),
              SizedBox(width: 10),
              _MethodBadge(icon: Icons.account_balance_wallet, label: 'Google Pay'),
              SizedBox(width: 10),
              _MethodBadge(icon: Icons.credit_card, label: 'Karte'),
            ],
          ),
          const SizedBox(height: 22),

          if (_error != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFE05A5A).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE05A5A)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline,
                      color: Color(0xFFE05A5A), size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _error!,
                      style: const TextStyle(
                          color: Color(0xFFE05A5A), fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],

          // Haupt-Button: Stripe Checkout.
          ElevatedButton(
            onPressed: _processing
                ? null
                : () => _run(_service.payForResult(
                      amountMinor: widget.amountMinor,
                      description: widget.description,
                    )),
            child: _processing
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.black),
                  )
                : Text('${PaymentConfig.format(widget.amountMinor)} BEZAHLEN'),
          ),

          // Optionale Krypto-Zahlung.
          if (cryptoFuture != null) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _processing ? null : () => _run(cryptoFuture),
              icon: const Icon(Icons.currency_bitcoin, size: 18),
              label: const Text('MIT KRYPTO BEZAHLEN'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.gold,
                side: const BorderSide(color: AppTheme.goldDark),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ],

          const SizedBox(height: 8),
          if (PaymentConfig.sandbox)
            const Text(
              '🧪 Sandbox-Modus – es wird KEIN echtes Geld belastet',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
            ),
          TextButton(
            onPressed: _processing ? null : () => Navigator.of(context).pop(false),
            child: const Text('Abbrechen'),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock, size: 12, color: AppTheme.textSecondary),
              const SizedBox(width: 4),
              Text(
                'Sicher bezahlen mit Stripe',
                style: TextStyle(
                  color: AppTheme.textSecondary.withValues(alpha: 0.8),
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MethodBadge extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MethodBadge({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppTheme.textPrimary),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
                color: AppTheme.textPrimary, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
