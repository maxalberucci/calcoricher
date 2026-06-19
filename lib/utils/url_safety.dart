/// Sicherheits-Helfer für vom Benutzer eingegebene Links.
///
/// Profil-Links sind frei eingebbar und werden auf der ÖFFENTLICHEN Profilkarte
/// für andere antippbar dargestellt. Ohne Schema-Prüfung könnte ein Link auf
/// `javascript:`, `file:`, `tel:`, `intent:` o. ä. zeigen und beim Antippen
/// unerwünschte Aktionen auslösen. Wir erlauben deshalb ausschließlich
/// http(s)-Web-Links – beim Speichern UND erneut unmittelbar vor dem Öffnen
/// (Defense-in-Depth, da die gespeicherten Daten lokal manipulierbar sind).
class UrlSafety {
  UrlSafety._();

  static const Set<String> _allowedSchemes = {'http', 'https'};

  /// Wandelt eine Roh-Eingabe in einen sicheren http(s)-Link um oder gibt `null`
  /// zurück, wenn daraus kein gültiger, sicherer Web-Link entstehen kann.
  ///
  /// Schemalose Eingaben (z. B. `example.com`) werden als `https://` behandelt.
  /// Ein explizit angegebenes Schema muss http/https sein – `javascript:`,
  /// `file:`, `tel:`, `mailto:` usw. werden abgewiesen.
  static String? normalize(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return null;

    // Explizites Schema vorhanden? Dann ausschließlich http/https erlauben.
    final schemeMatch =
        RegExp(r'^([a-zA-Z][a-zA-Z0-9+.\-]*):').firstMatch(value);
    if (schemeMatch != null) {
      final scheme = schemeMatch.group(1)!.toLowerCase();
      if (scheme != 'http' && scheme != 'https') return null;
      final uri = Uri.tryParse(value);
      if (uri == null || !isSafeWebUri(uri)) return null;
      return uri.toString();
    }

    // Kein Schema -> als https behandeln.
    final uri = Uri.tryParse('https://$value');
    if (uri == null || !isSafeWebUri(uri)) return null;
    return uri.toString();
  }

  /// Ob [uri] gefahrlos extern geöffnet werden darf (nur http/https mit Host).
  static bool isSafeWebUri(Uri uri) =>
      _allowedSchemes.contains(uri.scheme.toLowerCase()) && uri.host.isNotEmpty;
}
