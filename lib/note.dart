// Model pojedynczej notatki
class Note {
  final int? id;
  final String title;
  final String content;
  final int createdAt; // timestamp w milisekundach
  final int? reminderAt; // timestamp przypomnienia (null = brak)
  final int colorIndex; // indeks koloru z palety (0 = domyslny)
  final bool pinned; // czy notatka przypieta na gorze
  final int? folderId; // przynaleznosc do folderu (null = bez folderu)

  Note({
    this.id,
    required this.title,
    required this.content,
    required this.createdAt,
    this.reminderAt,
    this.colorIndex = 0,
    this.pinned = false,
    this.folderId,
  });

  // Konwersja do mapy (zapis do bazy)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'createdAt': createdAt,
      'reminderAt': reminderAt,
      'colorIndex': colorIndex,
      'pinned': pinned ? 1 : 0,
      'folderId': folderId,
    };
  }

  // Odczyt z mapy (z bazy)
  factory Note.fromMap(Map<String, dynamic> map) {
    return Note(
      id: map['id'] as int?,
      title: map['title'] as String,
      content: map['content'] as String,
      createdAt: map['createdAt'] as int,
      reminderAt: map['reminderAt'] as int?,
      colorIndex: (map['colorIndex'] as int?) ?? 0,
      pinned: (map['pinned'] as int?) == 1,
      folderId: map['folderId'] as int?,
    );
  }

  // Eksport do JSON (kopia zapasowa)
  Map<String, dynamic> toJson() => toMap();

  // Import z JSON
  factory Note.fromJson(Map<String, dynamic> json) => Note.fromMap(json);

  // Kopia z modyfikacjami
  Note copyWith({
    int? id,
    String? title,
    String? content,
    int? createdAt,
    int? reminderAt,
    int? colorIndex,
    bool? pinned,
    int? folderId,
    bool clearReminder = false,
    bool clearFolder = false,
  }) {
    return Note(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      reminderAt: clearReminder ? null : (reminderAt ?? this.reminderAt),
      colorIndex: colorIndex ?? this.colorIndex,
      pinned: pinned ?? this.pinned,
      folderId: clearFolder ? null : (folderId ?? this.folderId),
    );
  }
}
