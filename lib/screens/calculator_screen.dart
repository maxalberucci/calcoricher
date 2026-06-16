import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/calculator_provider.dart';
import '../providers/user_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/calculator_button.dart';
import '../widgets/coin_display.dart';

class CalculatorScreen extends StatelessWidget {
  const CalculatorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserProvider>().currentUser;
    final calc = context.watch<CalculatorProvider>();

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('DER REICHEN-RECHNER'),
        actions: [
          if (user != null)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: CoinDisplay(coins: user.coins),
            ),
        ],
      ),
      body: Column(
        children: [
          // Tagline
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Text(
              'Rechnen ist für Arme, Zahlen ist für Reiche',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontStyle: FontStyle.italic,
                    letterSpacing: 0.5,
                  ),
              textAlign: TextAlign.center,
            ),
          ),

          // Display area
          Expanded(
            flex: 2,
            child: _DisplayPanel(calc: calc),
          ),

          // Cost + reveal button
          if (user != null)
            _CostBar(calc: calc)
          else
            _NoUserHint(),

          const Divider(height: 1, color: AppTheme.divider),

          // Calculator buttons
          Expanded(
            flex: 3,
            child: _ButtonGrid(calc: calc),
          ),

          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Display panel
// ---------------------------------------------------------------------------
class _DisplayPanel extends StatelessWidget {
  final CalculatorProvider calc;

  const _DisplayPanel({required this.calc});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.goldDark, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          // Expression
          Text(
            calc.expression,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 24,
              letterSpacing: 1,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.end,
          ),
          const SizedBox(height: 12),

          // Result area
          if (calc.isRevealed) ...[
            const Divider(color: AppTheme.goldDark),
            const SizedBox(height: 8),
            Text(
              '= ${calc.displayResult}',
              style: const TextStyle(
                color: AppTheme.gold,
                fontSize: 46,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.end,
            ),
          ] else if (calc.state == CalcState.error) ...[
            const Divider(color: AppTheme.goldDark),
            const SizedBox(height: 8),
            const Text(
              'Ungültige Rechnung',
              style: TextStyle(color: Colors.redAccent, fontSize: 20),
            ),
          ] else if (calc.isReadyToReveal) ...[
            // Calculated but not yet paid — tease the user
            const Divider(color: AppTheme.goldDark),
            const SizedBox(height: 8),
            const Text(
              '= ???',
              style: TextStyle(
                color: AppTheme.divider,
                fontSize: 46,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Drücke „Resultat anzeigen" um die Wahrheit zu erfahren',
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 11,
                fontStyle: FontStyle.italic,
              ),
              textAlign: TextAlign.end,
            ),
          ] else ...[
            const Text(
              '???',
              style: TextStyle(
                color: AppTheme.divider,
                fontSize: 46,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Cost bar + reveal button
// ---------------------------------------------------------------------------
class _CostBar extends StatelessWidget {
  final CalculatorProvider calc;

  const _CostBar({required this.calc});

  @override
  Widget build(BuildContext context) {
    final userProv = context.watch<UserProvider>();
    final user = userProv.currentUser!;
    final price = user.nextPrice;
    final canAfford = user.canAffordNextResult;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Column(
        children: [
          // Price label
          RichText(
            text: TextSpan(
              style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
              children: [
                const TextSpan(text: 'Dieses Resultat kostet dich nur '),
                TextSpan(
                  text: '$price Coins',
                  style: const TextStyle(
                    color: AppTheme.gold,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const TextSpan(text: ' 🪙'),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Reveal button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: canAfford && !calc.isRevealed
                  ? () => _onReveal(context)
                  : null,
              icon: Icon(
                canAfford ? Icons.lock_open_rounded : Icons.lock_rounded,
                size: 18,
              ),
              label: Text(
                calc.isRevealed
                    ? 'RESULTAT ANGEZEIGT ✓'
                    : canAfford
                        ? 'RESULTAT ANZEIGEN  ($price Coins)'
                        : 'ZU WENIG COINS  (brauche $price)',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: calc.isRevealed
                    ? AppTheme.goldDark
                    : canAfford
                        ? AppTheme.gold
                        : AppTheme.card,
                foregroundColor: calc.isRevealed
                    ? AppTheme.textPrimary
                    : canAfford
                        ? Colors.black
                        : Colors.redAccent,
                side: (!canAfford && !calc.isRevealed)
                    ? const BorderSide(color: Colors.redAccent)
                    : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _onReveal(BuildContext context) async {
    final calcProv = context.read<CalculatorProvider>();
    final userProv = context.read<UserProvider>();

    // Evaluate if not already done.
    if (!calcProv.isReadyToReveal) {
      final ok = calcProv.evaluate();
      if (!ok) return; // Error shown in display.
    }

    // Deduct coins first, then reveal.
    final success = await userProv.spendCoins();
    if (!context.mounted) return;

    if (success) {
      calcProv.reveal();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Nicht genug Coins! Auch Reiche haben manchmal Grenzen. 💀',
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }
}

// ---------------------------------------------------------------------------
// Hint when no profile exists yet
// ---------------------------------------------------------------------------
class _NoUserHint extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.person_add, color: AppTheme.gold, size: 16),
          const SizedBox(width: 8),
          Text(
            'Gehe zu „Profil" um deinen Namen einzugeben',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Button grid
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
                    style: CalcButtonStyle.operator,
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
      children: tokens.map((t) {
        return Expanded(
          child: CalculatorButton(
            label: _label(t),
            style: _style(t),
            onTap: () => _onTap(t),
          ),
        );
      }).toList(),
    );
  }

  void _onTap(String token) {
    switch (token) {
      case 'AC':
        calc.clear();
      case '⌫':
        calc.backspace();
      case '%':
        // Append /100 to expression to calculate percentage.
        calc.addToken('/100');
      default:
        calc.addToken(token);
    }
  }

  CalcButtonStyle _style(String t) {
    if ('+-*/='.contains(t)) return CalcButtonStyle.operator;
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
