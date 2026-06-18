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
  });

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
      );
}
