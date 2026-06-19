import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import '../../legal/legal_meta.dart';
import '../../theme/app_theme.dart';
import '../../widgets/luxury_background.dart';
import '../../widgets/markdown_lite.dart';

/// Zeigt ein rechtliches Dokument (Datenschutz, AGB, Cookies) an. Der Text wird
/// aus dem Markdown-Asset geladen und mit [MarkdownLite] dargestellt.
class LegalDocumentScreen extends StatelessWidget {
  final LegalDocument document;

  const LegalDocumentScreen({super.key, required this.document});

  /// Bequemer Push-Helfer.
  static Future<void> open(BuildContext context, LegalDocument document) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LegalDocumentScreen(document: document),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(document.title.toUpperCase()),
      ),
      body: LuxuryBackground(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: FutureBuilder<String>(
                future: rootBundle.loadString(document.assetPath),
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(
                      child: CircularProgressIndicator(color: AppTheme.gold),
                    );
                  }
                  if (snapshot.hasError || !snapshot.hasData) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'Dieses Dokument konnte nicht geladen werden.',
                          style: TextStyle(color: AppTheme.textSecondary),
                        ),
                      ),
                    );
                  }
                  return SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
                    child: MarkdownLite(snapshot.data!),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
