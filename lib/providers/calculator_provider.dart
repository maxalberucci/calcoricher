import 'package:flutter/foundation.dart';
import 'package:math_expressions/math_expressions.dart';

enum CalcState {
  idle,       // Nothing evaluated yet
  calculated, // Evaluated, result hidden (shows "???")
  revealed,   // Result visible (paid)
  error,
}

class CalculatorProvider extends ChangeNotifier {
  String _expression = '';
  String _hiddenResult = ''; // Stored but not visible until revealed
  CalcState _state = CalcState.idle;

  String get expression => _expression.isEmpty ? '0' : _expression;
  CalcState get state => _state;

  /// The visible result — only available after calling reveal().
  String get displayResult => _state == CalcState.revealed ? _hiddenResult : '';

  /// Das berechnete Resultat (auch vor dem Aufdecken) — wird beim Bezahlen für
  /// den Verlauf benötigt und NICHT in der zensierten Anzeige verwendet.
  String get rawResult => _hiddenResult;

  bool get isRevealed => _state == CalcState.revealed;

  /// True when result is calculated and ready to be paid for.
  bool get isReadyToReveal =>
      _state == CalcState.calculated || _state == CalcState.revealed;

  void addToken(String token) {
    // After a reveal, start fresh.
    if (_state == CalcState.revealed) {
      _expression = '';
      _hiddenResult = '';
      _state = CalcState.idle;
    }

    // Prevent double operators in a row.
    if (_isOperator(token) &&
        _expression.isNotEmpty &&
        _isOperator(_expression[_expression.length - 1])) {
      _expression = _expression.substring(0, _expression.length - 1);
    }

    if (_expression.isEmpty && _isOperator(token) && token != '-') return;

    _expression += token;
    // Reset revealed/calculated state when editing.
    if (_state != CalcState.idle) _state = CalcState.idle;
    notifyListeners();
  }

  void backspace() {
    if (_state == CalcState.revealed) {
      clear();
      return;
    }
    if (_expression.isNotEmpty) {
      _expression = _expression.substring(0, _expression.length - 1);
      if (_state != CalcState.idle) _state = CalcState.idle;
      notifyListeners();
    }
  }

  void clear() {
    _expression = '';
    _hiddenResult = '';
    _state = CalcState.idle;
    notifyListeners();
  }

  /// Lädt ein früheres Resultat als Startwert, um damit weiterzurechnen
  /// (wie das Antippen eines Verlauf-Eintrags beim Windows-Rechner).
  void loadResult(String value) {
    _expression = value;
    _hiddenResult = '';
    _state = CalcState.idle;
    notifyListeners();
  }

  /// Evaluate and store result internally — does NOT show it.
  /// Returns true on success, false on parse error.
  bool evaluate() {
    if (_expression.isEmpty) return false;
    try {
      final expr = _expression.replaceAll('×', '*').replaceAll('÷', '/');
      final exp = ShuntingYardParser().parse(expr);
      final value = exp.evaluate(EvaluationType.REAL, ContextModel()) as double;

      if (value == value.truncateToDouble()) {
        _hiddenResult = value.toInt().toString();
      } else {
        _hiddenResult = value.toStringAsFixed(6)
            .replaceAll(RegExp(r'0+$'), '')
            .replaceAll(RegExp(r'\.$'), '');
      }
      _state = CalcState.calculated;
      notifyListeners();
      return true;
    } catch (_) {
      _state = CalcState.error;
      notifyListeners();
      return false;
    }
  }

  /// Make the stored result visible (called after successful coin deduction).
  void reveal() {
    if (_state == CalcState.calculated) {
      _state = CalcState.revealed;
      notifyListeners();
    }
  }

  bool _isOperator(String token) => '+-*/'.contains(token);
}
