class Note {
  final int? id;
  final String title;
  final String content;
  final String rawOcrText;
  final String imagePath;
  final List<String> tags;
  final String summary;
  final String sourceType;
  final String llmStatus;
  final int? scanSessionId;
  final DateTime createdAt;
  final DateTime updatedAt;

  Note({
    this.id,
    required this.title,
    required this.content,
    required this.rawOcrText,
    required this.imagePath,
    required this.tags,
    this.summary = '',
    this.sourceType = 'single_image',
    this.llmStatus = 'none',
    this.scanSessionId,
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
      'summary': summary,
      'source_type': sourceType,
      'llm_status': llmStatus,
      'scan_session_id': scanSessionId,
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
      summary: (map['summary'] ?? '').toString(),
      sourceType: (map['source_type'] ?? 'single_image').toString(),
      llmStatus: (map['llm_status'] ?? 'none').toString(),
      scanSessionId: map['scan_session_id'] is int
          ? map['scan_session_id'] as int
          : int.tryParse('${map['scan_session_id'] ?? ''}'),
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
    String? summary,
    String? sourceType,
    String? llmStatus,
    int? scanSessionId,
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
      summary: summary ?? this.summary,
      sourceType: sourceType ?? this.sourceType,
      llmStatus: llmStatus ?? this.llmStatus,
      scanSessionId: scanSessionId ?? this.scanSessionId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
