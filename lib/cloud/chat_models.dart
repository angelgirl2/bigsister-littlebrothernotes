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
    this.reactions = const <String, String>{},
    this.deliveredAt,
    this.readAt,
    this.isPinned = false,
    this.editedAt,
    this.localStatus,
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
  /// One reaction per participant (device id -> emoji).
  final Map<String, String> reactions;
  final DateTime? deliveredAt;
  final DateTime? readAt;
  final bool isPinned;
  final DateTime? editedAt;
  /// Local-only delivery state: pending, failed, or null when server-confirmed.
  final String? localStatus;

  bool get hasAttachment => attachmentId != null && attachmentId!.isNotEmpty;
  bool get isRead => readAt != null;
  bool get isDelivered => deliveredAt != null || isRead;

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    DateTime? parse(Object? value) {
      if (value == null) return null;
      final parsed = DateTime.tryParse(value.toString());
      return parsed?.toLocal();
    }
    final parsedReactions = <String, String>{};
    final rawReactions = json['reactions'];
    if (rawReactions is Map) {
      for (final entry in rawReactions.entries) {
        final emoji = entry.value?.toString() ?? '';
        if (emoji.isNotEmpty) parsedReactions[entry.key.toString()] = emoji;
      }
    }
    final legacyReaction = json['reaction']?.toString();
    if (parsedReactions.isEmpty && legacyReaction != null && legacyReaction.isNotEmpty) {
      parsedReactions['legacy'] = legacyReaction;
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
      reaction: legacyReaction,
      reactions: parsedReactions,
      deliveredAt: parse(json['delivered_at'] ?? json['deliveredAt']),
      readAt: parse(json['read_at'] ?? json['readAt']),
      isPinned: json['is_pinned'] == true || json['isPinned'] == true,
      editedAt: parse(json['edited_at'] ?? json['editedAt']),
      localStatus: json['localStatus']?.toString(),
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
