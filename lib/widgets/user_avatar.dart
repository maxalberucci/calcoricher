import 'dart:io';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Rundes Profilbild: zeigt das gewählte Foto, sonst die Initiale des Namens.
/// Bei fehlender Bilddatei wird automatisch auf die Initiale zurückgefallen.
class UserAvatar extends StatelessWidget {
  final String name;
  final String? imagePath;
  final double size;
  final bool bordered;

  const UserAvatar({
    super.key,
    required this.name,
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
              // Datei gelöscht/verschoben -> Initiale als Fallback.
              errorBuilder: (_, __, ___) => _initial(),
            ),
          )
        : _initial();

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

  String get _letter {
    final trimmed = name.trim();
    return trimmed.isEmpty ? '?' : trimmed.characters.first.toUpperCase();
  }

  Widget _initial() => Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: AppTheme.cardHigh,
        ),
        alignment: Alignment.center,
        child: Text(
          _letter,
          style: TextStyle(
            color: AppTheme.gold,
            fontSize: size * 0.42,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
}
