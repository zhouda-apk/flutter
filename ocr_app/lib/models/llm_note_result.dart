class LlmNoteResult {
  final int? id;
  final int sessionId;
  final int? noteId;
  final String taskType;
  final String promptVersion;
  final String modelName;
  final String inputHash;
  final String title;
  final String summary;
  final String organizedContent;
  final String tagsJson;
  final String warningsJson;
  final String status;
  final String? errorMessage;
  final DateTime createdAt;

  const LlmNoteResult({
    this.id,
    required this.sessionId,
    this.noteId,
    required this.taskType,
    required this.promptVersion,
    required this.modelName,
    required this.inputHash,
    required this.title,
    required this.summary,
    required this.organizedContent,
    this.tagsJson = '[]',
    this.warningsJson = '[]',
    required this.status,
    this.errorMessage,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'session_id': sessionId,
      'note_id': noteId,
      'task_type': taskType,
      'prompt_version': promptVersion,
      'model_name': modelName,
      'input_hash': inputHash,
      'title': title,
      'summary': summary,
      'organized_content': organizedContent,
      'tags_json': tagsJson,
      'warnings_json': warningsJson,
      'status': status,
      'error_message': errorMessage,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory LlmNoteResult.fromMap(Map<String, dynamic> map) {
    final createdAtStr = (map['created_at'] ?? '').toString();

    return LlmNoteResult(
      id: map['id'] is int ? map['id'] as int : int.tryParse('${map['id']}'),
      sessionId: map['session_id'] is int
          ? map['session_id'] as int
          : int.tryParse('${map['session_id']}') ?? 0,
      noteId: map['note_id'] is int
          ? map['note_id'] as int
          : int.tryParse('${map['note_id'] ?? ''}'),
      taskType: (map['task_type'] ?? '').toString(),
      promptVersion: (map['prompt_version'] ?? '').toString(),
      modelName: (map['model_name'] ?? '').toString(),
      inputHash: (map['input_hash'] ?? '').toString(),
      title: (map['title'] ?? '').toString(),
      summary: (map['summary'] ?? '').toString(),
      organizedContent: (map['organized_content'] ?? '').toString(),
      tagsJson: (map['tags_json'] ?? '[]').toString(),
      warningsJson: (map['warnings_json'] ?? '[]').toString(),
      status: (map['status'] ?? '').toString(),
      errorMessage: map['error_message']?.toString(),
      createdAt: DateTime.tryParse(createdAtStr) ?? DateTime.now(),
    );
  }

  LlmNoteResult copyWith({
    int? id,
    int? sessionId,
    int? noteId,
    String? taskType,
    String? promptVersion,
    String? modelName,
    String? inputHash,
    String? title,
    String? summary,
    String? organizedContent,
    String? tagsJson,
    String? warningsJson,
    String? status,
    String? errorMessage,
    DateTime? createdAt,
  }) {
    return LlmNoteResult(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      noteId: noteId ?? this.noteId,
      taskType: taskType ?? this.taskType,
      promptVersion: promptVersion ?? this.promptVersion,
      modelName: modelName ?? this.modelName,
      inputHash: inputHash ?? this.inputHash,
      title: title ?? this.title,
      summary: summary ?? this.summary,
      organizedContent: organizedContent ?? this.organizedContent,
      tagsJson: tagsJson ?? this.tagsJson,
      warningsJson: warningsJson ?? this.warningsJson,
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
