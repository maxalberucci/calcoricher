import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/calculator_provider.dart';
import '../providers/user_provider.dart';
import '../payments/payment_config.dart';
import '../theme/app_theme.dart';
import '../widgets/calculator_button.dart';
import '../widgets/gold_text.dart';
import '../widgets/history_drawer.dart';
import '../widgets/locked_result.dart';
import '../widgets/luxury_background.dart';
import '../widgets/luxury_button.dart';
import '../widgets/payment_sheet.dart';
import '../widgets/purchase_celebration.dart';

class CalculatorScreen extends StatefulWidget {
  const CalculatorScreen({super.key});

  @override
  State<CalculatorScreen> createState() => _CalculatorScreenState();
}

class _CalculatorScreenState extends State<CalculatorScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserProvider>().currentUser;
    final calc = context.watch<CalculatorProvider>();

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      // Von rechts ausklappbarer Verlauf (Icon oder Wischen vom rechten Rand).
      endDrawer: HistoryDrawer(
        onPick: (value) {
          calc.loadResult(value);
          Navigator.of(context).pop(); // Drawer schließen
        },
      ),
      appBar: AppBar(
        title: GoldText(
          'CALCORICHER',
          style: AppTheme.serif(const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            letterSpacing: 3,
          )),
        ),
        leading: user != null
            ? IconButton(
                icon: const Icon(Icons.history),
                tooltip: 'History',
                onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
              )
            : null,
        actions: [
          if (user != null)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: _SpentBadge(amountMinor: user.totalSpentMinor),
            ),
        ],
      ),
      body: LuxuryBackground(
        child: SafeArea(
          // Auf Tablets/breiten Geräten zentriert begrenzen — kein Auseinanderziehen.
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                children: [
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    child: Text(
                      'Calculating is for the poor, paying is for the rich',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontStyle: FontStyle.italic,
                            letterSpacing: 0.5,
                          ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  Expanded(flex: 2, child: _DisplayPanel(calc: calc)),
                  if (user != null)
                    _CostBar(calc: calc)
                  else
                    const _NoUserHint(),
                  const Divider(height: 1, color: AppTheme.divider),
                  Expanded(flex: 3, child: _ButtonGrid(calc: calc)),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Anzeige-Bereich (Rechnung + zensiertes/echtes Resultat)
// ---------------------------------------------------------------------------
class _DisplayPanel extends StatelessWidget {
  final CalculatorProvider calc;

  const _DisplayPanel({required this.calc});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppTheme.cardHigh, AppTheme.card],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.goldDark, width: 0.8),
        boxShadow: AppTheme.goldGlow(opacity: 0.12, blur: 22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          // Eingegebene Rechnung
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.bottomRight,
              child: Text(
                calc.expression,
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 28,
                  letterSpacing: 1,
                ),
                maxLines: 1,
                textAlign: TextAlign.end,
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Divider(color: AppTheme.goldDark),
          const SizedBox(height: 6),
          // Überlaufsicher: skaliert bei Platzmangel herunter (kein Overflow).
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: _ResultLine(calc: calc),
            ),
          ),
        ],
      ),
    );
  }
}

/// Zeigt das echte Resultat (nur nach Bezahlung), eine Fehlermeldung
/// oder die einheitliche Zensur an.
class _ResultLine extends StatelessWidget {
  final CalculatorProvider calc;

  const _ResultLine({required this.calc});

  @override
  Widget build(BuildContext context) {
    // Hinweis: Die Rechtsausrichtung & das Herunterskalieren übernimmt der
    // umschließende FittedBox in _DisplayPanel — hier nur intrinsische Widgets.
    if (calc.state == CalcState.error) {
      return const Text(
        'Invalid calculation',
        style: TextStyle(color: Color(0xFFE05A5A), fontSize: 22),
      );
    }

    if (calc.isRevealed) {
      return GoldText(
        '= ${calc.displayResult}',
        glow: true,
        style: AppTheme.serif(const TextStyle(
          fontSize: 52,
          fontWeight: FontWeight.bold,
        )),
      );
    }

    // Idle oder berechnet-aber-nicht-bezahlt → immer gleiche, edle Zensur.
    return const LockedResult();
  }
}

// ---------------------------------------------------------------------------
// Preis-Leiste + Bezahl-/Aufdeck-Button
// ---------------------------------------------------------------------------
class _CostBar extends StatelessWidget {
  final CalculatorProvider calc;

  const _CostBar({required this.calc});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserProvider>().currentUser!;
    final priceMinor = user.currentResultPriceMinor;
    final revealed = calc.isRevealed;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Column(
        children: [
          RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              style: const TextStyle(
                  fontSize: 13, color: AppTheme.textSecondary),
              children: [
                const TextSpan(text: 'This result costs you only '),
                TextSpan(
                  text: PaymentConfig.format(priceMinor),
                  style: const TextStyle(
                    color: AppTheme.gold,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const TextSpan(text: ' 💳'),
              ],
            ),
          ),
          const SizedBox(height: 10),
          LuxuryButton(
            onPressed: revealed ? null : () => _onReveal(context),
            icon: revealed ? Icons.check_circle : Icons.lock_open_rounded,
            label: revealed
                ? 'RESULT UNLOCKED'
                : 'UNLOCK  (${PaymentConfig.format(priceMinor)})',
          ),
        ],
      ),
    );
  }

  Future<void> _onReveal(BuildContext context) async {
    final calcProv = context.read<CalculatorProvider>();
    final userProv = context.read<UserProvider>();
    final user = userProv.currentUser;
    if (user == null) return;

    // Bei Bedarf zuerst auswerten (Resultat bleibt zensiert).
    if (!calcProv.isReadyToReveal) {
      if (!calcProv.evaluate()) return; // Fehler wird angezeigt.
    }

    final amount = user.currentResultPriceMinor;
    final expression = calcProv.expression;
    final result = calcProv.rawResult;

    final paid = await showPaymentSheet(
      context,
      amountMinor: amount,
      description: expression,
    );
    if (!context.mounted || !paid) return;

    await userProv.recordPurchase(
      amountMinor: amount,
      expression: expression,
      result: result,
    );
    calcProv.reveal();
    if (!context.mounted) return;
    await showPurchaseCelebration(context, amountMinor: amount);
  }
}

// ---------------------------------------------------------------------------
// Anzeige des insgesamt ausgegebenen Geldes (AppBar)
// ---------------------------------------------------------------------------
class _SpentBadge extends StatelessWidget {
  final int amountMinor;

  const _SpentBadge({required this.amountMinor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: AppTheme.cardHigh,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.gold, width: 1),
        boxShadow: AppTheme.goldGlow(opacity: 0.2, blur: 10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.diamond_outlined, size: 15, color: AppTheme.gold),
          const SizedBox(width: 6),
          Text(
            PaymentConfig.format(amountMinor),
            style: const TextStyle(
              color: AppTheme.gold,
              fontWeight: FontWeight.bold,
              fontSize: 14,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Hinweis, falls (theoretisch) kein Benutzer vorhanden ist
// ---------------------------------------------------------------------------
class _NoUserHint extends StatelessWidget {
  const _NoUserHint();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.person_off, color: AppTheme.gold, size: 16),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              'Please sign in to unlock results',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tasten-Raster
// ---------------------------------------------------------------------------
class _ButtonGrid extends StatelessWidget {
  final CalculatorProvider calc;

  const _ButtonGrid({required this.calc});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        children: [
          Expanded(child: _buildRow(['AC', '⌫', '%', '/'])),
          Expanded(child: _buildRow(['7', '8', '9', '*'])),
          Expanded(child: _buildRow(['4', '5', '6', '-'])),
          Expanded(child: _buildRow(['1', '2', '3', '+'])),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: CalculatorButton(
                    label: '0',
                    style: CalcButtonStyle.wide,
                    onTap: () => calc.addToken('0'),
                  ),
                ),
                Expanded(
                  child: CalculatorButton(
                    label: '.',
                    onTap: () => calc.addToken('.'),
                  ),
                ),
                Expanded(
                  child: CalculatorButton(
                    label: '=',
                    style: CalcButtonStyle.equals,
                    onTap: calc.evaluate,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRow(List<String> tokens) {
    return Row(
      children: tokens
          .map((t) => Expanded(
                child: CalculatorButton(
                  label: _label(t),
                  style: _style(t),
                  onTap: () => _onTap(t),
                ),
              ))
          .toList(),
    );
  }

  void _onTap(String token) {
    switch (token) {
      case 'AC':
        calc.clear();
      case '⌫':
        calc.backspace();
      case '%':
        calc.addToken('/100');
      default:
        calc.addToken(token);
    }
  }

  CalcButtonStyle _style(String t) {
    if ('+-*/'.contains(t)) return CalcButtonStyle.operator;
    if (t == 'AC' || t == '⌫' || t == '%') return CalcButtonStyle.action;
    return CalcButtonStyle.number;
  }

  String _label(String t) {
    switch (t) {
      case '*':
        return '×';
      case '/':
        return '÷';
      default:
        return t;
    }
  }
}
