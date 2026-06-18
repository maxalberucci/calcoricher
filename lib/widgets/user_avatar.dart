import 'dart:io';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Rundes Profilbild: zeigt das gewählte Foto, sonst den Emoji-Avatar.
/// Bei fehlender Bilddatei wird automatisch auf das Emoji zurückgefallen.
class UserAvatar extends StatelessWidget {
  final String emoji;
  final String? imagePath;
  final double size;
  final bool bordered;

  const UserAvatar({
    super.key,
    required this.emoji,
    this.imagePath,
    this.size = 40,
    this.bordered = false,
  });

  @override
  Widget build(BuildContext context) {
    final hasPhoto = imagePath != null && imagePath!.isNotEmpty;

    final Widget content = hasPhoto
        ? ClipOval(
            child: Image.file(
              File(imagePath!),
              width: size,
              height: size,
              fit: BoxFit.cover,
              // Datei gelöscht/verschoben -> Emoji als Fallback.
              errorBuilder: (_, __, ___) => _emoji(),
            ),
          )
        : _emoji();

    if (!bordered) {
      return SizedBox(width: size, height: size, child: Center(child: content));
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppTheme.cardHigh,
        border: Border.all(color: AppTheme.gold, width: 2),
        boxShadow: AppTheme.goldGlow(opacity: 0.3, blur: 24),
      ),
      child: ClipOval(child: Center(child: content)),
    );
  }

  Widget _emoji() => Center(
        child: Text(emoji, style: TextStyle(fontSize: size * 0.5)),
      );
}
