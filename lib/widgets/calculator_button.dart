import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

enum CalcButtonStyle { number, operator, action, wide }

class CalculatorButton extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: _backgroundColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _borderColor, width: 0.8),
          boxShadow: [
            BoxShadow(
              color: _shadowColor.withValues(alpha: 0.3),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: _textColor,
              fontSize: style == CalcButtonStyle.wide ? 20 : 22,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ),
    );
  }

  Color get _backgroundColor {
    switch (style) {
      case CalcButtonStyle.operator:
        return AppTheme.goldDark.withValues(alpha: 0.25);
      case CalcButtonStyle.action:
        return AppTheme.card;
      case CalcButtonStyle.wide:
        return AppTheme.card;
      case CalcButtonStyle.number:
        return AppTheme.surface;
    }
  }

  Color get _textColor {
    switch (style) {
      case CalcButtonStyle.operator:
        return AppTheme.goldLight;
      case CalcButtonStyle.action:
        return AppTheme.textSecondary;
      case CalcButtonStyle.wide:
      case CalcButtonStyle.number:
        return AppTheme.textPrimary;
    }
  }

  Color get _borderColor {
    switch (style) {
      case CalcButtonStyle.operator:
        return AppTheme.goldDark;
      default:
        return AppTheme.divider;
    }
  }

  Color get _shadowColor {
    return style == CalcButtonStyle.operator ? AppTheme.gold : Colors.black;
  }
}
