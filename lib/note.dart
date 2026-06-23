// Model pojedynczej notatki
class Note {
  final int? id;
  final String title;
  final String content;
  final int createdAt; // timestamp w milisekundach
  final int? reminderAt; // timestamp przypomnienia (null = brak)

  Note({
    this.id,
    required this.title,
    required this.content,
    required this.createdAt,
    this.reminderAt,
  });

  // Konwersja do mapy (zapis do bazy)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'createdAt': createdAt,
      'reminderAt': reminderAt,
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
    );
  }

  // Kopia z modyfikacjami
  Note copyWith({
    int? id,
    String? title,
    String? content,
    int? createdAt,
    int? reminderAt,
    bool clearReminder = false,
  }) {
    return Note(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      reminderAt: clearReminder ? null : (reminderAt ?? this.reminderAt),
    );
  }
}
