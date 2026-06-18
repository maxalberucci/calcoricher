import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

enum CalcButtonStyle { number, operator, action, wide, equals }

/// Edler Rechner-Button. Skaliert dank [FittedBox] automatisch mit der
/// verfügbaren Fläche, sodass auf keinem Gerät etwas abgeschnitten wird.
class CalculatorButton extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  final CalcButtonStyle style;

  const CalculatorButton({
    super.key,
    required this.label,
    required this.onTap,
    this.style = CalcButtonStyle.number,
  });

  @override
  State<CalculatorButton> createState() => _CalculatorButtonState();
}

class _CalculatorButtonState extends State<CalculatorButton> {
  bool _pressed = false;

  bool get _isEquals => widget.style == CalcButtonStyle.equals;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.93 : 1.0,
        duration: const Duration(milliseconds: 80),
        child: Container(
          margin: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: _isEquals ? null : _backgroundColor,
            gradient: _isEquals ? AppTheme.goldGradient : null,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _borderColor, width: 0.8),
            boxShadow: [
              BoxShadow(
                color: _shadowColor.withValues(alpha: _isEquals ? 0.4 : 0.3),
                blurRadius: _isEquals ? 12 : 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  widget.label,
                  style: TextStyle(
                    color: _textColor,
                    fontSize: 26,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Color get _backgroundColor {
    switch (widget.style) {
      case CalcButtonStyle.operator:
        return AppTheme.goldDark.withValues(alpha: 0.22);
      case CalcButtonStyle.action:
        return AppTheme.cardHigh;
      case CalcButtonStyle.wide:
        return AppTheme.card;
      case CalcButtonStyle.number:
        return AppTheme.surface;
      case CalcButtonStyle.equals:
        return AppTheme.gold;
    }
  }

  Color get _textColor {
    switch (widget.style) {
      case CalcButtonStyle.operator:
        return AppTheme.goldLight;
      case CalcButtonStyle.action:
        return AppTheme.textSecondary;
      case CalcButtonStyle.equals:
        return Colors.black;
      case CalcButtonStyle.wide:
      case CalcButtonStyle.number:
        return AppTheme.textPrimary;
    }
  }

  Color get _borderColor {
    switch (widget.style) {
      case CalcButtonStyle.operator:
        return AppTheme.goldDark;
      case CalcButtonStyle.equals:
        return AppTheme.goldLight;
      default:
        return AppTheme.divider;
    }
  }

  Color get _shadowColor =>
      (widget.style == CalcButtonStyle.operator || _isEquals)
          ? AppTheme.gold
          : Colors.black;
}
