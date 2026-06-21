class RoomModel {
  final String id;
  final String code;
  final String title;
  final String ownerId;
  final List<String> members;
  final String createdAt;

  const RoomModel({
    required this.id,
    required this.code,
    required this.title,
    required this.ownerId,
    required this.members,
    required this.createdAt,
  });

  factory RoomModel.fromJson(Map<String, dynamic> json) => RoomModel(
        id: json['id'] as String? ?? '',
        code: json['code'] as String? ?? '',
        title: json['title'] as String? ?? '',
        ownerId: json['ownerId'] as String? ?? '',
        members: (json['members'] as List?)?.whereType<String>().toList() ??
            const [],
        createdAt: json['createdAt'] as String? ?? '',
      );
}
