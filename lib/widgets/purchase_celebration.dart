import 'dart:math';
import 'package:flutter/material.dart';
import '../payments/payment_config.dart';
import '../theme/app_theme.dart';
import 'gold_text.dart';

/// Stufe der Kauf-Animation – je mehr Geld, desto opulenter.
class _Tier {
  final String label;
  final String subtitle;
  final IconData icon;
  final int particleCount;
  final Duration duration;
  final List<Color> colors;
  final bool flash;

  const _Tier({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.particleCount,
    required this.duration,
    required this.colors,
    required this.flash,
  });
}

const List<Color> _gold = [AppTheme.goldLight, AppTheme.gold, AppTheme.goldDark];
const List<Color> _rich = [
  AppTheme.goldLight,
  AppTheme.gold,
  AppTheme.champagne,
  AppTheme.goldDark,
];
const List<Color> _royal = [
  AppTheme.goldLight,
  AppTheme.gold,
  AppTheme.champagne,
  AppTheme.platinum,
  AppTheme.goldDark,
];

/// Wählt die Animationsstufe anhand des bezahlten Betrags (Minor-Units).
_Tier _tierFor(int amountMinor) {
  final major = amountMinor / 100;
  if (major < 5) {
    return const _Tier(
      label: 'NICE',
      subtitle: 'A taste of the good life',
      icon: Icons.check_circle_rounded,
      particleCount: 16,
      duration: Duration(milliseconds: 1600),
      colors: _gold,
      flash: false,
    );
  }
  if (major < 25) {
    return const _Tier(
      label: 'RICH',
      subtitle: 'Money well spent',
      icon: Icons.paid_rounded,
      particleCount: 30,
      duration: Duration(milliseconds: 2000),
      colors: _gold,
      flash: false,
    );
  }
  if (major < 100) {
    return const _Tier(
      label: 'LUXURY',
      subtitle: 'Exquisite taste',
      icon: Icons.workspace_premium_rounded,
      particleCount: 48,
      duration: Duration(milliseconds: 2400),
      colors: _rich,
      flash: true,
    );
  }
  if (major < 1000) {
    return const _Tier(
      label: 'ROYAL',
      subtitle: 'Fit for nobility',
      icon: Icons.diamond_rounded,
      particleCount: 78,
      duration: Duration(milliseconds: 2900),
      colors: _royal,
      flash: true,
    );
  }
  return const _Tier(
    label: 'BILLIONAIRE',
    subtitle: 'A purchase of legend',
    icon: Icons.emoji_events_rounded,
    particleCount: 130,
    duration: Duration(milliseconds: 3500),
    colors: _royal,
    flash: true,
  );
}

/// Zeigt nach einem erfolgreichen Kauf eine luxuriöse Glückwunsch-Animation.
/// Aufwand und Dauer skalieren mit dem bezahlten Betrag.
Future<void> showPurchaseCelebration(
  BuildContext context, {
  required int amountMinor,
}) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'celebration',
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 250),
    pageBuilder: (_, __, ___) =>
        _CelebrationOverlay(amountMinor: amountMinor, tier: _tierFor(amountMinor)),
    transitionBuilder: (_, anim, __, child) =>
        FadeTransition(opacity: anim, child: child),
  );
}

class _CelebrationOverlay extends StatefulWidget {
  final int amountMinor;
  final _Tier tier;

  const _CelebrationOverlay({required this.amountMinor, required this.tier});

  @override
  State<_CelebrationOverlay> createState() => _CelebrationOverlayState();
}

class _CelebrationOverlayState extends State<_CelebrationOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final List<_Particle> _particles;

  @override
  void initState() {
    super.initState();
    final random = Random();
    _particles = List.generate(
      widget.tier.particleCount,
      (_) => _Particle.random(random, widget.tier.colors),
    );
    _controller = AnimationController(vsync: this, duration: widget.tier.duration)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed && mounted) {
          Navigator.of(context).maybePop();
        }
      })
      ..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tier = widget.tier;

    return GestureDetector(
      onTap: () => Navigator.of(context).maybePop(),
      behavior: HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final p = _controller.value;
          // Sanftes Ein-/Ausblenden des Scrims.
          final scrim = (p < 0.85 ? 1.0 : (1 - (p - 0.85) / 0.15)).clamp(0.0, 1.0);
          // Zentraler Auftritt: elastisch hereinskalieren, am Ende ausblenden.
          final inScale = Curves.elasticOut.transform((p / 0.45).clamp(0.0, 1.0));
          final outFade =
              (p < 0.85 ? 1.0 : (1 - (p - 0.85) / 0.15)).clamp(0.0, 1.0);
          final glow = 0.35 + 0.25 * sin(p * pi * 6);
          // Kurzer Lichtblitz für höhere Stufen.
          final flash = tier.flash ? (1 - (p / 0.18).clamp(0.0, 1.0)) * 0.5 : 0.0;

          return Stack(
            fit: StackFit.expand,
            children: [
              Container(color: Colors.black.withValues(alpha: 0.78 * scrim)),
              if (flash > 0)
                Container(color: AppTheme.goldLight.withValues(alpha: flash)),
              // Goldregen.
              CustomPaint(
                painter: _ParticlePainter(progress: p, particles: _particles),
                size: Size.infinite,
              ),
              // Zentrale Botschaft.
              Center(
                child: Opacity(
                  opacity: outFade,
                  child: Transform.scale(
                    scale: inScale,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const RadialGradient(
                              colors: [AppTheme.cardHigh, AppTheme.surface],
                            ),
                            border: Border.all(color: AppTheme.gold, width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.gold.withValues(alpha: glow),
                                blurRadius: 40,
                                spreadRadius: 4,
                              ),
                            ],
                          ),
                          child: Icon(tier.icon, color: AppTheme.gold, size: 60),
                        ),
                        const SizedBox(height: 22),
                        GoldText(
                          tier.label,
                          glow: true,
                          style: const TextStyle(
                            fontSize: 34,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 3,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          tier.subtitle,
                          style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 13,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                        const SizedBox(height: 18),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 22, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.45),
                            borderRadius: BorderRadius.circular(30),
                            border: Border.all(color: AppTheme.gold),
                          ),
                          child: GoldText(
                            '− ${PaymentConfig.format(widget.amountMinor)}',
                            style: const TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Einzelnes fallendes Teilchen (Goldmünze oder Funke).
class _Particle {
  final double x; // Start-X (0..1)
  final double drift; // horizontale Auslenkung
  final double size;
  final double speed;
  final double delay;
  final double phase;
  final bool sparkle;
  final Color color;

  const _Particle({
    required this.x,
    required this.drift,
    required this.size,
    required this.speed,
    required this.delay,
    required this.phase,
    required this.sparkle,
    required this.color,
  });

  factory _Particle.random(Random r, List<Color> palette) {
    return _Particle(
      x: r.nextDouble(),
      drift: (r.nextDouble() - 0.5) * 0.18,
      size: 5 + r.nextDouble() * 9,
      speed: 0.8 + r.nextDouble() * 0.6,
      delay: r.nextDouble() * 0.35,
      phase: r.nextDouble() * pi * 2,
      sparkle: r.nextBool(),
      color: palette[r.nextInt(palette.length)],
    );
  }
}

class _ParticlePainter extends CustomPainter {
  final double progress;
  final List<_Particle> particles;

  _ParticlePainter({required this.progress, required this.particles});

  @override
  void paint(Canvas canvas, Size size) {
    for (final particle in particles) {
      final local = ((progress * particle.speed) - particle.delay);
      if (local <= 0) continue;
      final fall = local.clamp(0.0, 1.3);

      final dy = (-0.1 + fall * 1.25) * size.height;
      if (dy < -20 || dy > size.height + 20) continue;
      final dx = (particle.x + particle.drift * sin(fall * pi * 2 + particle.phase)) *
          size.width;

      final fade = fall > 0.85 ? (1 - (fall - 0.85) / 0.45).clamp(0.0, 1.0) : 1.0;
      final center = Offset(dx, dy);

      if (particle.sparkle) {
        _drawSparkle(canvas, center, particle.size, particle.color, fade);
      } else {
        _drawCoin(canvas, center, particle.size, particle.color, fade);
      }
    }
  }

  void _drawCoin(
      Canvas canvas, Offset center, double radius, Color color, double fade) {
    final rect = Rect.fromCircle(center: center, radius: radius);
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [
          AppTheme.goldLight.withValues(alpha: fade),
          color.withValues(alpha: fade),
        ],
      ).createShader(rect);
    canvas.drawCircle(center, radius, paint);
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = AppTheme.goldDark.withValues(alpha: fade),
    );
  }

  void _drawSparkle(
      Canvas canvas, Offset center, double size, Color color, double fade) {
    final paint = Paint()..color = color.withValues(alpha: fade);
    final path = Path();
    final r = size;
    final r2 = size * 0.34;
    for (var i = 0; i < 4; i++) {
      final a = i * pi / 2;
      final tip = Offset(center.dx + cos(a) * r, center.dy + sin(a) * r);
      final side = Offset(
        center.dx + cos(a + pi / 4) * r2,
        center.dy + sin(a + pi / 4) * r2,
      );
      if (i == 0) {
        path.moveTo(tip.dx, tip.dy);
      } else {
        path.lineTo(tip.dx, tip.dy);
      }
      path.lineTo(side.dx, side.dy);
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_ParticlePainter oldDelegate) =>
      oldDelegate.progress != progress;
}
