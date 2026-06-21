class FeedItem {
  final String id;
  final String purchaseId;
  final String receiptId;
  final String by;
  final String userId;
  final String expression;
  final String result;
  final int amountMinor;
  final String shareText;
  final String? roomCode;
  final String? challengeSlug;
  final String? charityCampaignId;
  final String timestamp;

  const FeedItem({
    required this.id,
    required this.purchaseId,
    required this.receiptId,
    required this.by,
    required this.userId,
    required this.expression,
    required this.result,
    required this.amountMinor,
    required this.shareText,
    required this.roomCode,
    required this.challengeSlug,
    required this.charityCampaignId,
    required this.timestamp,
  });

  factory FeedItem.fromJson(Map<String, dynamic> json) => FeedItem(
        id: json['id'] as String? ?? '',
        purchaseId: json['purchaseId'] as String? ?? '',
        receiptId: json['receiptId'] as String? ?? '',
        by: json['by'] as String? ?? '',
        userId: json['userId'] as String? ?? '',
        expression: json['expression'] as String? ?? '',
        result: json['result'] as String? ?? '',
        amountMinor: json['amountMinor'] as int? ?? 0,
        shareText: json['shareText'] as String? ?? '',
        roomCode: json['roomCode'] as String?,
        challengeSlug: json['challengeSlug'] as String?,
        charityCampaignId: json['charityCampaignId'] as String?,
        timestamp: json['timestamp'] as String? ?? '',
      );
}
