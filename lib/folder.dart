// Model folderu (kategorii notatek)
class NoteFolder {
  final int? id;
  final String name;
  final int createdAt;

  NoteFolder({
    this.id,
    required this.name,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'createdAt': createdAt,
    };
  }

  factory NoteFolder.fromMap(Map<String, dynamic> map) {
    return NoteFolder(
      id: map['id'] as int?,
      name: map['name'] as String,
      createdAt: map['createdAt'] as int,
    );
  }

  Map<String, dynamic> toJson() => toMap();
  factory NoteFolder.fromJson(Map<String, dynamic> json) =>
      NoteFolder.fromMap(json);
}
