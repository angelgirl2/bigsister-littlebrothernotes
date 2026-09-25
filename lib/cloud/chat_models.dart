class ChatMessage {
  ChatMessage({
    required this.id,
    required this.senderId,
    required this.type,
    required this.body,
    required this.createdAt,
    this.attachmentId,
    this.attachmentName,
    this.replyTo,
    this.reaction,
    this.deliveredAt,
    this.readAt,
  });

  final String id;
  final String senderId;
  final String type;
  final String body;
  final DateTime createdAt;
  final String? attachmentId;
  final String? attachmentName;
  final String? replyTo;
  final String? reaction;
  final DateTime? deliveredAt;
  final DateTime? readAt;

  bool get hasAttachment => attachmentId != null && attachmentId!.isNotEmpty;
  bool get isRead => readAt != null;
  bool get isDelivered => deliveredAt != null || isRead;

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    DateTime? parse(Object? value) {
      if (value == null) return null;
      final parsed = DateTime.tryParse(value.toString());
      return parsed?.toLocal();
    }
    return ChatMessage(
      id: json['id']?.toString() ?? '',
      senderId: json['sender_id']?.toString() ?? json['senderId']?.toString() ?? '',
      type: json['type']?.toString() ?? 'text',
      body: json['body']?.toString() ?? '',
      createdAt: parse(json['created_at'] ?? json['createdAt']) ?? DateTime.now(),
      attachmentId: json['attachment_id']?.toString() ?? json['attachmentId']?.toString(),
      attachmentName: json['attachment_name']?.toString() ?? json['attachmentName']?.toString(),
      replyTo: json['reply_to']?.toString() ?? json['replyTo']?.toString(),
      reaction: json['reaction']?.toString(),
      deliveredAt: parse(json['delivered_at'] ?? json['deliveredAt']),
      readAt: parse(json['read_at'] ?? json['readAt']),
    );
  }
}

class CloudMember {
  CloudMember({required this.id, required this.role, required this.label, this.lastSeenAt});
  final String id;
  final String role;
  final String label;
  final DateTime? lastSeenAt;

  factory CloudMember.fromJson(Map<String, dynamic> json) => CloudMember(
        id: json['id']?.toString() ?? '',
        role: json['role']?.toString() ?? '',
        label: json['label']?.toString() ?? '',
        lastSeenAt: json['last_seen_at'] == null ? null : DateTime.tryParse(json['last_seen_at'].toString())?.toLocal(),
      );
}


class CloudLetter {
  CloudLetter({
    required this.id,
    required this.senderId,
    required this.title,
    required this.body,
    required this.createdAt,
    this.readAt,
  });

  final String id;
  final String senderId;
  final String title;
  final String body;
  final DateTime createdAt;
  final DateTime? readAt;

  bool get isRead => readAt != null;

  factory CloudLetter.fromJson(Map<String, dynamic> json) {
    DateTime? parse(Object? value) {
      if (value == null) return null;
      final parsed = DateTime.tryParse(value.toString());
      return parsed?.toLocal();
    }
    return CloudLetter(
      id: json['id']?.toString() ?? '',
      senderId: json['sender_id']?.toString() ?? json['senderId']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      body: json['body']?.toString() ?? '',
      createdAt: parse(json['created_at'] ?? json['createdAt']) ?? DateTime.now(),
      readAt: parse(json['read_at'] ?? json['readAt']),
    );
  }
}
