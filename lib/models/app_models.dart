import 'dart:convert';

enum NoteKind { note, checklist, letter, memory }
enum AppThemeChoice { turquoise, sky, red, blue }

enum NoteFolder { personal, ideas, tasks, memories, letters, dreams, private }

extension NoteFolderLabel on NoteFolder {
  String get label => switch (this) {
        NoteFolder.personal => 'شخصی',
        NoteFolder.ideas => 'ایده‌ها',
        NoteFolder.tasks => 'کارها',
        NoteFolder.memories => 'خاطره‌ها',
        NoteFolder.letters => 'نامه‌ها',
        NoteFolder.dreams => 'رویاها',
        NoteFolder.private => 'خصوصی',
      };
}

class CheckItem {
  CheckItem({required this.text, this.done = false});
  String text;
  bool done;
  Map<String, dynamic> toJson() => {'text': text, 'done': done};
  factory CheckItem.fromJson(Map<String, dynamic> json) => CheckItem(text: json['text'] as String? ?? '', done: json['done'] as bool? ?? false);
}

class NoteItem {
  NoteItem({
    required this.id,
    required this.title,
    required this.body,
    required this.createdAt,
    required this.updatedAt,
    this.kind = NoteKind.note,
    this.folder = NoteFolder.personal,
    this.tags = const [],
    this.favorite = false,
    this.pinned = false,
    this.completed = false,
    this.checkItems = const [],
    this.imagePaths = const [],
    this.audioPath,
    this.reminderAt,
    this.deletedAt,
    this.textSize = 17,
    this.bold = false,
    this.italic = false,
    this.underline = false,
  });

  final String id;
  String title;
  String body;
  DateTime createdAt;
  DateTime updatedAt;
  NoteKind kind;
  NoteFolder folder;
  List<String> tags;
  bool favorite;
  bool pinned;
  bool completed;
  List<CheckItem> checkItems;
  List<String> imagePaths;
  String? audioPath;
  DateTime? reminderAt;
  DateTime? deletedAt;
  double textSize;
  bool bold;
  bool italic;
  bool underline;

  bool get inTrash => deletedAt != null;
  bool get hasReminder => reminderAt != null;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'body': body,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'kind': kind.name,
        'folder': folder.name,
        'tags': tags,
        'favorite': favorite,
        'pinned': pinned,
        'completed': completed,
        'checkItems': checkItems.map((e) => e.toJson()).toList(),
        'imagePaths': imagePaths,
        'imagePath': imagePaths.isEmpty ? null : imagePaths.first,
        'audioPath': audioPath,
        'reminderAt': reminderAt?.toIso8601String(),
        'deletedAt': deletedAt?.toIso8601String(),
        'textSize': textSize,
        'bold': bold,
        'italic': italic,
        'underline': underline,
      };

  factory NoteItem.fromJson(Map<String, dynamic> json) {
    final legacyImage = json['imagePath'] as String?;
    final images = ((json['imagePaths'] as List?) ?? (legacyImage == null ? const [] : [legacyImage]))
        .whereType<String>()
        .toList();
    return NoteItem(
      id: json['id'] as String? ?? DateTime.now().microsecondsSinceEpoch.toString(),
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ?? DateTime.now(),
      kind: NoteKind.values.firstWhere((e) => e.name == json['kind'], orElse: () => NoteKind.note),
      folder: NoteFolder.values.firstWhere((e) => e.name == json['folder'], orElse: () => NoteFolder.personal),
      tags: ((json['tags'] as List?) ?? const []).whereType<String>().toList(),
      favorite: json['favorite'] as bool? ?? false,
      pinned: json['pinned'] as bool? ?? false,
      completed: json['completed'] as bool? ?? false,
      checkItems: ((json['checkItems'] as List?) ?? const []).map((e) => CheckItem.fromJson(Map<String, dynamic>.from(e as Map))).toList(),
      imagePaths: images,
      audioPath: json['audioPath'] as String?,
      reminderAt: json['reminderAt'] == null ? null : DateTime.tryParse(json['reminderAt'] as String),
      deletedAt: json['deletedAt'] == null ? null : DateTime.tryParse(json['deletedAt'] as String),
      textSize: (json['textSize'] as num?)?.toDouble() ?? 17,
      bold: json['bold'] as bool? ?? false,
      italic: json['italic'] as bool? ?? false,
      underline: json['underline'] as bool? ?? false,
    );
  }
}

class AppSnapshot {
  AppSnapshot({required this.notes, required this.theme, required this.lockEnabled, required this.pin, required this.biometric});
  final List<NoteItem> notes;
  final AppThemeChoice theme;
  final bool lockEnabled;
  final String? pin;
  final bool biometric;
  Map<String, dynamic> toJson() => {
        'version': 2,
        'notes': notes.map((e) => e.toJson()).toList(),
        'theme': theme.name,
        'lockEnabled': lockEnabled,
        'pin': pin,
        'biometric': biometric,
        'exportedAt': DateTime.now().toIso8601String(),
      };
  String encode() => jsonEncode(toJson());
}
