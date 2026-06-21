class ReceiptModel {
  final String id;
  final String purchaseId;
  final String expression;
  final String result;
  final int amountMinor;
  final int? rank;
  final String shareText;
  final String imageUrl;
  final String timestamp;

  const ReceiptModel({
    required this.id,
    required this.purchaseId,
    required this.expression,
    required this.result,
    required this.amountMinor,
    this.rank,
    required this.shareText,
    required this.imageUrl,
    required this.timestamp,
  });

  factory ReceiptModel.fromJson(Map<String, dynamic> json) => ReceiptModel(
        id: json['id'] as String? ?? '',
        purchaseId: json['purchaseId'] as String? ?? '',
        expression: json['expression'] as String? ?? '',
        result: json['result'] as String? ?? '',
        amountMinor: json['amountMinor'] as int? ?? 0,
        rank: json['rank'] as int?,
        shareText: json['shareText'] as String? ?? '',
        imageUrl: json['imageUrl'] as String? ?? '',
        timestamp: json['timestamp'] as String? ?? '',
      );
}
