import 'package:flutter/material.dart';

/// Beschreibt ein rechtliches Dokument, das als Markdown-Asset vorliegt und in
/// der App über den [MarkdownLite]-Renderer angezeigt wird.
///
/// Die Markdown-Dateien unter `assets/legal/` sind die **einzige Quelle** für
/// die Texte – sie werden hier nur referenziert, nicht dupliziert.
class LegalDocument {
  final String title;
  final String assetPath;
  final IconData icon;

  const LegalDocument({
    required this.title,
    required this.assetPath,
    required this.icon,
  });
}

/// Zentrale Metadaten zu den Rechtstexten und zur Einwilligungs-Version.
class LegalMeta {
  LegalMeta._();

  /// Wird bei inhaltlichen Änderungen an den Rechtstexten erhöht. Stimmt die
  /// gespeicherte Einwilligungs-Version nicht mehr überein, wird der Nutzer
  /// erneut um Zustimmung gebeten. Muss zur Kopfzeile der Markdown-Dateien
  /// passen.
  static const int consentVersion = 1;

  static const LegalDocument privacy = LegalDocument(
    title: 'Datenschutzerklärung',
    assetPath: 'assets/legal/datenschutz.md',
    icon: Icons.privacy_tip_outlined,
  );

  static const LegalDocument terms = LegalDocument(
    title: 'AGB',
    assetPath: 'assets/legal/agb.md',
    icon: Icons.description_outlined,
  );

  static const LegalDocument cookies = LegalDocument(
    title: 'Cookie- & Speicher-Hinweis',
    assetPath: 'assets/legal/cookies.md',
    icon: Icons.cookie_outlined,
  );

  static const List<LegalDocument> all = [privacy, terms, cookies];
}
