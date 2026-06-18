import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Text mit poliertem Edelmetall-Verlauf statt flacher Goldfarbe.
///
/// Legt [AppTheme.metallicGold] per [ShaderMask] über die Glyphen – das ergibt
/// den reflektierenden „Luxusmarken"-Look für Markenname, Resultat & Preise.
/// Optional sorgt [glow] für einen weichen Goldschimmer hinter dem Text.
class GoldText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final TextAlign? textAlign;
  final Gradient gradient;
  final bool glow;

  const GoldText(
    this.text, {
    super.key,
    this.style,
    this.textAlign,
    this.gradient = AppTheme.metallicGold,
    this.glow = false,
  });

  @override
  Widget build(BuildContext context) {
    final base = (style ?? const TextStyle()).copyWith(
      color: Colors.white, // wird vom Shader überschrieben (BlendMode.srcIn)
      shadows: glow
          ? [
              BoxShadow(
                color: AppTheme.gold.withValues(alpha: 0.35),
                blurRadius: 16,
              ),
            ]
          : null,
    );

    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (bounds) => gradient.createShader(
        Rect.fromLTWH(0, 0, bounds.width, bounds.height),
      ),
      child: Text(text, textAlign: textAlign, style: base),
    );
  }
}
