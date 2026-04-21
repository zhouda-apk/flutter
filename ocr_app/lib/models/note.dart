class Note {
  final int? id;
  final String title;
  final String content;
  final String rawOcrText;
  final String imagePath;
  final List<String> tags;
  final DateTime createdAt;
  final DateTime updatedAt;

  Note({
    this.id,
    required this.title,
    required this.content,
    required this.rawOcrText,
    required this.imagePath,
    required this.tags,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'raw_ocr_text': rawOcrText,
      'image_path': imagePath,
      'tags': tags.join(','),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory Note.fromMap(Map<String, dynamic> map) {
    final createdAtStr = (map['created_at'] ?? '').toString();
    final updatedAtStr = (map['updated_at'] ?? '').toString();

    return Note(
      id: map['id'] is int ? map['id'] as int : int.tryParse('${map['id']}'),
      title: (map['title'] ?? '').toString(),
      content: (map['content'] ?? '').toString(),
      rawOcrText: (map['raw_ocr_text'] ?? '').toString(),
      imagePath: (map['image_path'] ?? '').toString(),
      tags: ((map['tags'] ?? '').toString()).isEmpty
          ? []
          : ((map['tags'] ?? '').toString()).split(','),
      createdAt: DateTime.tryParse(createdAtStr) ?? DateTime.now(),
      updatedAt: DateTime.tryParse(updatedAtStr) ?? DateTime.now(),
    );
  }

  Note copyWith({
    int? id,
    String? title,
    String? content,
    String? rawOcrText,
    String? imagePath,
    List<String>? tags,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Note(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      rawOcrText: rawOcrText ?? this.rawOcrText,
      imagePath: imagePath ?? this.imagePath,
      tags: tags ?? this.tags,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
