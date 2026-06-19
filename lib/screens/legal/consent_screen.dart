import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../legal/consent_service.dart';
import '../../legal/legal_meta.dart';
import '../../theme/app_theme.dart';
import '../../widgets/luxury_background.dart';
import '../../widgets/luxury_button.dart';
import 'legal_document_screen.dart';

/// Einwilligungs-Dialog für Datenschutz, AGB und „Cookies" (lokale Speicherung).
///
/// Zwei Modi:
/// * **Erststart** ([next] gesetzt): wird vor der Nutzung angezeigt; nach der
///   Entscheidung geht es zu [next] weiter.
/// * **Verwaltung** ([next] == null): über das Profil erreichbar, um die
///   Einwilligung zu ändern oder zu widerrufen.
class ConsentScreen extends StatefulWidget {
  final Widget? next;

  const ConsentScreen({super.key, this.next});

  @override
  State<ConsentScreen> createState() => _ConsentScreenState();
}

class _ConsentScreenState extends State<ConsentScreen> {
  bool _optional = false;
  bool _showDetails = false;

  bool get _manageMode => widget.next == null;

  @override
  void initState() {
    super.initState();
    final consent = context.read<ConsentService>();
    _optional = consent.optionalAccepted;
    _showDetails = _manageMode; // Im Verwaltungsmodus direkt aufgeklappt.
  }

  Future<void> _accept(bool optional) async {
    await context.read<ConsentService>().accept(optional: optional);
    if (!mounted) return;
    if (_manageMode) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Einstellungen gespeichert.'),
          backgroundColor: AppTheme.goldDark,
        ),
      );
      Navigator.of(context).pop();
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => widget.next!),
      );
    }
  }

  Future<void> _revoke() async {
    await context.read<ConsentService>().revoke();
    if (!mounted) return;
    setState(() => _optional = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Einwilligung widerrufen.')),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: _manageMode
          ? AppBar(title: const Text('DATENSCHUTZ-EINSTELLUNGEN'))
          : null,
      body: LuxuryBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(Icons.cookie_outlined,
                        color: AppTheme.gold, size: 44),
                    const SizedBox(height: 16),
                    Text(
                      'Datenschutz & Cookies',
                      textAlign: TextAlign.center,
                      style: AppTheme.serif(const TextStyle(
                        color: AppTheme.gold,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      )),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Calcoricher speichert dein Konto, deine Käufe und deine '
                      'Einstellungen technisch notwendig auf deinem Gerät. '
                      'Es gibt kein Tracking und keine Werbung. Mit dem '
                      'Fortfahren akzeptierst du die AGB und nimmst die '
                      'Datenschutzerklärung zur Kenntnis.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 13.5,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _LegalLinks(),
                    const SizedBox(height: 8),
                    if (!_manageMode)
                      Align(
                        alignment: Alignment.center,
                        child: TextButton.icon(
                          onPressed: () =>
                              setState(() => _showDetails = !_showDetails),
                          icon: Icon(
                            _showDetails
                                ? Icons.expand_less
                                : Icons.tune,
                            size: 18,
                          ),
                          label: Text(
                            _showDetails ? 'Weniger' : 'Einstellungen',
                          ),
                        ),
                      ),
                    if (_showDetails) ...[
                      const SizedBox(height: 4),
                      const _CategoryTile(
                        title: 'Notwendig',
                        subtitle:
                            'Konto, Sicherheit und lokale Speicherung deiner '
                            'App-Daten. Erforderlich für den Betrieb.',
                        value: true,
                        locked: true,
                      ),
                      const SizedBox(height: 10),
                      _CategoryTile(
                        title: 'Optionale & externe Dienste',
                        subtitle:
                            'Externe Zahlungs- und Inhaltsdienste (z. B. '
                            'Stripe-Checkout, verlinkte Profile). Aktuell keine '
                            'Analyse- oder Werbe-Cookies.',
                        value: _optional,
                        locked: false,
                        onChanged: (v) => setState(() => _optional = v),
                      ),
                      const SizedBox(height: 16),
                    ],
                    const SizedBox(height: 8),
                    if (_manageMode) ...[
                      LuxuryButton(
                        label: 'AUSWAHL SPEICHERN',
                        icon: Icons.save,
                        onPressed: () => _accept(_optional),
                      ),
                      const SizedBox(height: 10),
                      TextButton(
                        onPressed: _revoke,
                        child: const Text(
                          'Einwilligung widerrufen',
                          style: TextStyle(color: Color(0xFFE05A5A)),
                        ),
                      ),
                    ] else ...[
                      LuxuryButton(
                        label: 'ALLE AKZEPTIEREN',
                        icon: Icons.verified,
                        onPressed: () => _accept(true),
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton(
                        onPressed: () => _accept(_showDetails ? _optional : false),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.gold,
                          side: const BorderSide(color: AppTheme.goldDark),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: Text(
                          _showDetails ? 'AUSWAHL SPEICHERN' : 'NUR NOTWENDIGE',
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Antippbare Links zu den drei Rechtsdokumenten.
class _LegalLinks extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 6,
      runSpacing: 4,
      children: [
        for (final doc in LegalMeta.all)
          TextButton(
            onPressed: () => LegalDocumentScreen.open(context, doc),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(doc.title, style: const TextStyle(fontSize: 12.5)),
          ),
      ],
    );
  }
}

/// Eine Einwilligungs-Kategorie mit Schalter (oder fixiert für „Notwendig").
class _CategoryTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final bool locked;
  final ValueChanged<bool>? onChanged;

  const _CategoryTile({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.locked,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          locked
              ? const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10),
                  child: Icon(Icons.lock, size: 18, color: AppTheme.goldDark),
                )
              : Switch(
                  value: value,
                  activeThumbColor: Colors.black,
                  activeTrackColor: AppTheme.gold,
                  onChanged: onChanged,
                ),
        ],
      ),
    );
  }
}
