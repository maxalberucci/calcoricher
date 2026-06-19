import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'legal_meta.dart';

/// Verwaltet die Einwilligung des Nutzers in Datenschutz/AGB und in optionale
/// Dienste (Cookie-/Speicher-Einwilligung). Der Zustand wird lokal in
/// [SharedPreferences] gespeichert und ist **versioniert**: Wird der Rechtstext
/// geändert (siehe [LegalMeta.consentVersion]), muss erneut zugestimmt werden.
class ConsentService extends ChangeNotifier {
  static const _keyVersion = 'legal_consent_version';
  static const _keyOptional = 'legal_consent_optional';
  static const _keyTimestamp = 'legal_consent_at';

  int? _acceptedVersion;
  bool _optional = false;
  bool _initialized = false;

  bool get isInitialized => _initialized;

  /// Hat der Nutzer der aktuellen Fassung zugestimmt?
  bool get hasConsented => _acceptedVersion == LegalMeta.consentVersion;

  /// Wurde optionalen Diensten (z. B. externe Zahlungs-/Inhaltsdienste)
  /// zugestimmt?
  bool get optionalAccepted => _optional;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _acceptedVersion = prefs.getInt(_keyVersion);
    _optional = prefs.getBool(_keyOptional) ?? false;
    _initialized = true;
    notifyListeners();
  }

  /// Speichert die Entscheidung. [optional] = optionale Dienste akzeptiert.
  Future<void> accept({required bool optional}) async {
    final prefs = await SharedPreferences.getInstance();
    _acceptedVersion = LegalMeta.consentVersion;
    _optional = optional;
    await prefs.setInt(_keyVersion, LegalMeta.consentVersion);
    await prefs.setBool(_keyOptional, optional);
    await prefs.setInt(_keyTimestamp, DateTime.now().millisecondsSinceEpoch);
    notifyListeners();
  }

  /// Widerruft die Einwilligung vollständig (führt beim nächsten Start erneut
  /// zum Einwilligungs-Dialog).
  Future<void> revoke() async {
    final prefs = await SharedPreferences.getInstance();
    _acceptedVersion = null;
    _optional = false;
    await prefs.remove(_keyVersion);
    await prefs.remove(_keyOptional);
    await prefs.remove(_keyTimestamp);
    notifyListeners();
  }
}
