/// Konfiguration der Admin-Rechte.
///
/// Nur Konten mit einer hier gelisteten E-Mail sehen das Report-Tool und können
/// gemeldete Kommentare löschen oder verwerfen. Weitere Admins einfach in die
/// Menge aufnehmen.
class AdminConfig {
  AdminConfig._();

  static const Set<String> adminEmails = {
    'max.alberucci@gmail.com',
  };

  static bool isAdmin(String? email) =>
      email != null && adminEmails.contains(email.trim().toLowerCase());
}
