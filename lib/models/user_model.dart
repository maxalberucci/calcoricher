import 'dart:math';
import '../payments/payment_config.dart';
import 'history_entry.dart';

/// Datenmodell eines Benutzers.
///
/// Es wird mit ECHTEM Geld pro Resultat bezahlt. Der Preis verdoppelt sich pro
/// freigeschaltetem Resultat: Basispreis × 1, ×2, ×4, ×8 … Beträge werden in
/// Minor-Units (z. B. Rappen/Cent) als [int] geführt — keine Float-Fehler.
class UserModel {
  final String id;
  String username;
  String email;

  /// Emoji-Avatar (Fallback, wenn kein Foto gewählt ist).
  String avatar;

  /// Pfad zu einem selbst gewählten Profilbild (Kamera/Galerie). null = Emoji.
  String? avatarPath;

  /// Insgesamt mit echtem Geld ausgegebener Betrag in Minor-Units (Cent).
  int totalSpentMinor;

  /// Anzahl freigeschalteter Resultate (treibt die Preisverdopplung).
  int unlockedResultsCount;

  /// Verlauf der freigeschalteten Rechnungen (neueste zuerst).
  List<HistoryEntry> history;

  /// Anzahl bezahlter Namensänderungen (für Achievements).
  int usernameChanges;

  /// Wie oft ein Operator in freigeschalteten Rechnungen vorkam ('+','-','*','/').
  Map<String, int> operatorCounts;

  UserModel({
    required this.id,
    required this.username,
    required this.email,
    this.avatar = '👑',
    this.avatarPath,
    this.totalSpentMinor = 0,
    this.unlockedResultsCount = 0,
    List<HistoryEntry>? history,
    this.usernameChanges = 0,
    Map<String, int>? operatorCounts,
  })  : history = history ?? [],
        operatorCounts = operatorCounts ?? {};

  /// Wie oft [op] in freigeschalteten Rechnungen genutzt wurde.
  int operatorCount(String op) => operatorCounts[op] ?? 0;

  /// Preis-Multiplikator für das nächste Resultat: 1, 2, 4, 8, 16 …
  int get currentPriceMultiplier => pow(2, unlockedResultsCount).toInt();

  /// Preis für das nächste Resultat in Minor-Units (Cent).
  int get currentResultPriceMinor =>
      currentPriceMultiplier * PaymentConfig.basePriceMinor;

  Map<String, dynamic> toJson() => {
        'id': id,
        'username': username,
        'email': email,
        'avatar': avatar,
        'avatarPath': avatarPath,
        'totalSpentMinor': totalSpentMinor,
        'unlockedResultsCount': unlockedResultsCount,
        'history': history.map((e) => e.toJson()).toList(),
        'usernameChanges': usernameChanges,
        'operatorCounts': operatorCounts,
      };

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
        id: json['id'] as String? ?? json['email'] as String? ?? '',
        username: json['username'] as String? ?? json['name'] as String? ?? '',
        email: json['email'] as String? ?? '',
        avatar: json['avatar'] as String? ?? '👑',
        avatarPath: json['avatarPath'] as String?,
        totalSpentMinor: json['totalSpentMinor'] as int? ?? 0,
        unlockedResultsCount: json['unlockedResultsCount'] as int? ?? 0,
        history: (json['history'] as List?)
                ?.map((e) => HistoryEntry.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        usernameChanges: json['usernameChanges'] as int? ?? 0,
        operatorCounts: (json['operatorCounts'] as Map?)
                ?.map((k, v) => MapEntry(k as String, v as int)) ??
            {},
      );
}
