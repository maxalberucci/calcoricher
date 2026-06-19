/// Eine Meldung („Report") zu einem Kommentar.
class CommentReport {
  final String reporterId;
  final String reporterName;
  final String reason;
  final int timestamp;

  const CommentReport({
    required this.reporterId,
    required this.reporterName,
    required this.reason,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'reporterId': reporterId,
        'reporterName': reporterName,
        'reason': reason,
        'timestamp': timestamp,
      };

  factory CommentReport.fromJson(Map<String, dynamic> json) => CommentReport(
        reporterId: json['reporterId'] as String? ?? '',
        reporterName: json['reporterName'] as String? ?? 'Unknown',
        reason: json['reason'] as String? ?? '',
        timestamp: json['timestamp'] as int? ?? 0,
      );
}

class ProfileComment {
  final String id;
  final String authorId;
  final String authorName;
  final String authorAvatar;
  final String? authorAvatarPath;
  final String text;
  final int timestamp;
  String? ownerReply;
  int? ownerReplyTimestamp;

  /// Meldungen zu diesem Kommentar (für das Admin-Report-Tool).
  List<CommentReport> reports;

  ProfileComment({
    required this.id,
    required this.authorId,
    required this.authorName,
    required this.authorAvatar,
    this.authorAvatarPath,
    required this.text,
    required this.timestamp,
    this.ownerReply,
    this.ownerReplyTimestamp,
    List<CommentReport>? reports,
  }) : reports = reports ?? [];

  /// Wurde dieser Kommentar bereits vom Benutzer [userId] gemeldet?
  bool isReportedBy(String userId) =>
      reports.any((report) => report.reporterId == userId);

  Map<String, dynamic> toJson() => {
        'id': id,
        'authorId': authorId,
        'authorName': authorName,
        'authorAvatar': authorAvatar,
        'authorAvatarPath': authorAvatarPath,
        'text': text,
        'timestamp': timestamp,
        'ownerReply': ownerReply,
        'ownerReplyTimestamp': ownerReplyTimestamp,
        'reports': reports.map((r) => r.toJson()).toList(),
      };

  factory ProfileComment.fromJson(Map<String, dynamic> json) => ProfileComment(
        id: json['id'] as String? ?? '',
        authorId: json['authorId'] as String? ?? '',
        authorName: json['authorName'] as String? ?? 'Unknown',
        authorAvatar: json['authorAvatar'] as String? ?? '👑',
        authorAvatarPath: json['authorAvatarPath'] as String?,
        text: json['text'] as String? ?? '',
        timestamp: json['timestamp'] as int? ?? 0,
        ownerReply: json['ownerReply'] as String?,
        ownerReplyTimestamp: json['ownerReplyTimestamp'] as int?,
        reports: (json['reports'] as List?)
                ?.map((e) => CommentReport.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
      );
}
