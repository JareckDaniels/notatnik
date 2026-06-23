// Model folderu (kategorii notatek)
class NoteFolder {
  final int? id;
  final String name;
  final int createdAt;
  final int position; // reczna kolejnosc na liscie folderow
  final bool expanded; // true = otwarty (notatki widoczne na ekranie glownym)

  NoteFolder({
    this.id,
    required this.name,
    required this.createdAt,
    this.position = 0,
    this.expanded = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'createdAt': createdAt,
      'position': position,
      'expanded': expanded ? 1 : 0,
    };
  }

  factory NoteFolder.fromMap(Map<String, dynamic> map) {
    return NoteFolder(
      id: map['id'] as int?,
      name: map['name'] as String,
      createdAt: map['createdAt'] as int,
      position: (map['position'] as int?) ?? 0,
      expanded: (map['expanded'] as int?) == 1,
    );
  }

  NoteFolder copyWith({
    int? id,
    String? name,
    int? createdAt,
    int? position,
    bool? expanded,
  }) {
    return NoteFolder(
      id: id ?? this.id,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
      position: position ?? this.position,
      expanded: expanded ?? this.expanded,
    );
  }

  Map<String, dynamic> toJson() => toMap();
  factory NoteFolder.fromJson(Map<String, dynamic> json) =>
      NoteFolder.fromMap(json);
}
