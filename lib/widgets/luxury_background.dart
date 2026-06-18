import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Edler, dunkler Verlaufshintergrund mit dezentem Goldschimmer.
/// Wird hinter allen Hauptbildschirmen verwendet.
class LuxuryBackground extends StatelessWidget {
  final Widget child;

  const LuxuryBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
      child: Stack(
        children: [
          // Dezenter Goldschein oben für Tiefe.
          Positioned(
            top: -120,
            left: 0,
            right: 0,
            child: Container(
              height: 240,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppTheme.gold.withValues(alpha: 0.10),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}
