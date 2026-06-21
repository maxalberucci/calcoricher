import 'dart:math';
import 'feed_item.dart';
import '../payments/payment_config.dart';
import 'history_entry.dart';
import 'profile_comment.dart';
import 'receipt_model.dart';

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

  /// Kurzer persönlicher Claim unter dem Namen.
  String profileTitle;

  /// Freier Profiltext für die öffentliche Profilkarte.
  String bio;

  /// Antippbare Links, die auf der Profilkarte gezeigt werden.
  List<String> links;

  /// Index des gewählten Profil-Akzents.
  int profileAccentIndex;

  /// Insgesamt mit echtem Geld ausgegebener Betrag in Minor-Units (Cent).
  int totalSpentMinor;

  /// Anzahl freigeschalteter Resultate (treibt die Preisverdopplung).
  int unlockedResultsCount;

  /// Höchster für ein einzelnes Resultat bezahlter Betrag (Minor-Units).
  int highestUnlockMinor;

  /// Verlauf der freigeschalteten Rechnungen (neueste zuerst).
  List<HistoryEntry> history;

  /// Öffentliche Kommentare auf dem Profil (neueste zuerst).
  List<ProfileComment> profileComments;

  /// Noch nicht angesehene neue Kommentare auf dem eigenen Profil (Badge).
  int unreadCommentCount;

  /// Noch nicht angesehene Antworten auf eigene Kommentare (Badge).
  int unreadReplyCount;

  /// Anzahl bezahlter Namensänderungen (für Achievements).
  int usernameChanges;

  /// Gesperrt durch einen Admin – ein gebanntes Konto kann sich nicht einloggen.
  bool isBanned;

  /// Wie oft ein Operator in freigeschalteten Rechnungen vorkam ('+','-','*','/').
  Map<String, int> operatorCounts;

  UserModel({
    required this.id,
    required this.username,
    required this.email,
    this.avatar = '👑',
    this.avatarPath,
    this.profileTitle = '',
    this.bio = '',
    List<String>? links,
    this.profileAccentIndex = 0,
    this.totalSpentMinor = 0,
    this.unlockedResultsCount = 0,
    this.highestUnlockMinor = 0,
    List<HistoryEntry>? history,
    List<ProfileComment>? profileComments,
    this.unreadCommentCount = 0,
    this.unreadReplyCount = 0,
    this.usernameChanges = 0,
    this.isBanned = false,
    Map<String, int>? operatorCounts,
  })  : links = links ?? [],
        history = history ?? [],
        profileComments = profileComments ?? [],
        operatorCounts = operatorCounts ?? {};

  /// Wie oft [op] in freigeschalteten Rechnungen genutzt wurde.
  int operatorCount(String op) => operatorCounts[op] ?? 0;

  /// Preis-Multiplikator für das nächste Resultat: 1, 2, 4, 8, 16 …
  int get currentPriceMultiplier => pow(2, unlockedResultsCount).toInt();

  /// Preis für das nächste Resultat in Minor-Units (Cent).
  int get currentResultPriceMinor =>
      currentPriceMultiplier * PaymentConfig.basePriceMinor;

  List<ReceiptModel> get receiptGallery => history
      .map((entry) => ReceiptModel(
            id: 'receipt_${id}_${entry.timestamp}',
            purchaseId: 'purchase_${id}_${entry.timestamp}',
            expression: entry.expression,
            result: entry.result,
            amountMinor: entry.amountMinor,
            rank: entry.rank,
            shareText:
                'I paid ${PaymentConfig.format(entry.amountMinor)} for this answer.',
            imageUrl: '/api/receipts/receipt_${id}_${entry.timestamp}.svg',
            timestamp: DateTime.fromMillisecondsSinceEpoch(entry.timestamp)
                .toIso8601String(),
          ))
      .toList();

  List<String> get flexTitles {
    final titles = <String>[];
    if (receiptGallery.isNotEmpty) titles.add('Receipt Collector');
    if (totalSpentMinor >= 10000) titles.add('Patron of Pointless Math');
    if (unlockedResultsCount >= 10) titles.add('Serial Revealer');
    if (luxuryFrame.tier >= 2) titles.add(luxuryFrame.name);
    return titles;
  }

  LuxuryFrame get luxuryFrame {
    if (totalSpentMinor >= 100000) {
      return const LuxuryFrame(
        name: 'Black Diamond Frame',
        rarity: 'Mythic',
        tier: 3,
      );
    }
    if (highestUnlockMinor >= PaymentConfig.dailySpendLimitMinor ||
        totalSpentMinor >= 50000) {
      return const LuxuryFrame(
        name: 'Diamond Frame',
        rarity: 'Rare',
        tier: 2,
      );
    }
    if (receiptGallery.length >= 3 || totalSpentMinor >= 5000) {
      return const LuxuryFrame(
        name: 'Gilded Frame',
        rarity: 'Uncommon',
        tier: 1,
      );
    }
    return const LuxuryFrame(
      name: 'Classic Gold Frame',
      rarity: 'Common',
      tier: 0,
    );
  }

  FeedItem feedItemFor(HistoryEntry entry) => FeedItem(
        id: 'feed_${id}_${entry.timestamp}',
        purchaseId: 'purchase_${id}_${entry.timestamp}',
        receiptId: 'receipt_${id}_${entry.timestamp}',
        by: username,
        userId: id,
        expression: entry.expression,
        result: entry.result,
        amountMinor: entry.amountMinor,
        shareText:
            'I paid ${PaymentConfig.format(entry.amountMinor)} for this answer.',
        roomCode: entry.roomCode,
        challengeSlug: entry.challengeSlug,
        charityCampaignId: entry.charityCampaignId,
        timestamp: DateTime.fromMillisecondsSinceEpoch(entry.timestamp)
            .toIso8601String(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'username': username,
        'email': email,
        'avatar': avatar,
        'avatarPath': avatarPath,
        'profileTitle': profileTitle,
        'bio': bio,
        'links': links,
        'profileAccentIndex': profileAccentIndex,
        'totalSpentMinor': totalSpentMinor,
        'unlockedResultsCount': unlockedResultsCount,
        'highestUnlockMinor': highestUnlockMinor,
        'history': history.map((e) => e.toJson()).toList(),
        'profileComments': profileComments.map((e) => e.toJson()).toList(),
        'unreadCommentCount': unreadCommentCount,
        'unreadReplyCount': unreadReplyCount,
        'usernameChanges': usernameChanges,
        'isBanned': isBanned,
        'operatorCounts': operatorCounts,
      };

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
        id: json['id'] as String? ?? json['email'] as String? ?? '',
        username: json['username'] as String? ?? json['name'] as String? ?? '',
        email: json['email'] as String? ?? '',
        avatar: json['avatar'] as String? ?? '👑',
        avatarPath: json['avatarPath'] as String?,
        profileTitle: json['profileTitle'] as String? ?? '',
        bio: json['bio'] as String? ?? '',
        links: (json['links'] as List?)
                ?.whereType<String>()
                .map((e) => e.trim())
                .where((e) => e.isNotEmpty)
                .toList() ??
            [],
        profileAccentIndex: json['profileAccentIndex'] as int? ?? 0,
        totalSpentMinor: json['totalSpentMinor'] as int? ?? 0,
        unlockedResultsCount: json['unlockedResultsCount'] as int? ?? 0,
        highestUnlockMinor: json['highestUnlockMinor'] as int? ?? 0,
        history: (json['history'] as List?)
                ?.map((e) => HistoryEntry.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        profileComments: (json['profileComments'] as List?)
                ?.map((e) => ProfileComment.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        unreadCommentCount: json['unreadCommentCount'] as int? ?? 0,
        unreadReplyCount: json['unreadReplyCount'] as int? ?? 0,
        usernameChanges: json['usernameChanges'] as int? ?? 0,
        isBanned: json['isBanned'] as bool? ?? false,
        operatorCounts: (json['operatorCounts'] as Map?)
                ?.map((k, v) => MapEntry(k as String, v as int)) ??
            {},
      );
}

class LuxuryFrame {
  final String name;
  final String rarity;
  final int tier;

  const LuxuryFrame({
    required this.name,
    required this.rarity,
    required this.tier,
  });
}
