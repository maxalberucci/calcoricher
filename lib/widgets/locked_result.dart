import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Professionelle, einheitliche Zensur des Resultats.
///
/// Zeigt einen verschwommenen Platzhalter mit laufendem Goldschimmer und einem
/// Schloss-Chip. Breite und Aussehen sind IMMER identisch — das echte Resultat
/// und sogar dessen Länge bleiben verborgen.
class LockedResult extends StatefulWidget {
  const LockedResult({super.key});

  @override
  State<LockedResult> createState() => _LockedResultState();
}

class _LockedResultState extends State<LockedResult>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shimmer;

  @override
  void initState() {
    super.initState();
    _shimmer = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _shimmer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Verschwommener Platzhalter mit Schimmer (fixe Breite -> kein Leak).
          ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 7, sigmaY: 7),
            child: AnimatedBuilder(
              animation: _shimmer,
              builder: (context, _) {
                final v = _shimmer.value;
                return Container(
                  width: 230,
                  height: 60,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: LinearGradient(
                      colors: const [
                        AppTheme.goldDark,
                        AppTheme.goldLight,
                        AppTheme.goldDark,
                      ],
                      stops: [
                        (v - 0.3).clamp(0.0, 1.0),
                        v.clamp(0.0, 1.0),
                        (v + 0.3).clamp(0.0, 1.0),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          // Schloss-Chip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: AppTheme.gold, width: 1),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lock_rounded, color: AppTheme.gold, size: 18),
                SizedBox(width: 8),
                Text(
                  'LOCKED',
                  style: TextStyle(
                    color: AppTheme.gold,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
