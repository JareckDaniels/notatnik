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
  final int position; // reczna kolejnosc (mniejsze = wyzej)
  final int? deletedAt; // timestamp wyrzucenia do kosza (null = nie w koszu)
  final bool forceAlarm; // true = ta notatka dzwoni jak budzik niezaleznie od globalnego
  final bool isList; // true = notatka jest lista zadan
  final String listItems; // pozycje listy jako JSON (gdy isList)

  Note({
    this.id,
    required this.title,
    required this.content,
    required this.createdAt,
    this.reminderAt,
    this.colorIndex = 0,
    this.pinned = false,
    this.folderId,
    this.position = 0,
    this.deletedAt,
    this.forceAlarm = false,
    this.isList = false,
    this.listItems = '[]',
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
      'position': position,
      'deletedAt': deletedAt,
      'forceAlarm': forceAlarm ? 1 : 0,
      'isList': isList ? 1 : 0,
      'listItems': listItems,
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
      position: (map['position'] as int?) ?? 0,
      deletedAt: map['deletedAt'] as int?,
      forceAlarm: (map['forceAlarm'] as int?) == 1,
      isList: (map['isList'] as int?) == 1,
      listItems: (map['listItems'] as String?) ?? '[]',
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
    int? position,
    int? deletedAt,
    bool? forceAlarm,
    bool? isList,
    String? listItems,
    bool clearReminder = false,
    bool clearDeleted = false,
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
      position: position ?? this.position,
      deletedAt: clearDeleted ? null : (deletedAt ?? this.deletedAt),
      forceAlarm: forceAlarm ?? this.forceAlarm,
      isList: isList ?? this.isList,
      listItems: listItems ?? this.listItems,
    );
  }
}

// Pojedyncza pozycja listy zadan
class ListItem {
  final String text;
  final bool checked;

  ListItem({required this.text, this.checked = false});

  Map<String, dynamic> toJson() => {'text': text, 'checked': checked};

  factory ListItem.fromJson(Map<String, dynamic> json) => ListItem(
        text: (json['text'] as String?) ?? '',
        checked: (json['checked'] as bool?) ?? false,
      );

  ListItem copyWith({String? text, bool? checked}) =>
      ListItem(text: text ?? this.text, checked: checked ?? this.checked);
}
