class ScanSession {
  final int? id;
  final String status;
  final String source;
  final int pageCount;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? errorMessage;

  const ScanSession({
    this.id,
    required this.status,
    required this.source,
    required this.pageCount,
    required this.createdAt,
    required this.updatedAt,
    this.errorMessage,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'status': status,
      'source': source,
      'page_count': pageCount,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'error_message': errorMessage,
    };
  }

  factory ScanSession.fromMap(Map<String, dynamic> map) {
    final createdAtStr = (map['created_at'] ?? '').toString();
    final updatedAtStr = (map['updated_at'] ?? '').toString();

    return ScanSession(
      id: map['id'] is int ? map['id'] as int : int.tryParse('${map['id']}'),
      status: (map['status'] ?? '').toString(),
      source: (map['source'] ?? '').toString(),
      pageCount: map['page_count'] is int
          ? map['page_count'] as int
          : int.tryParse('${map['page_count']}') ?? 0,
      createdAt: DateTime.tryParse(createdAtStr) ?? DateTime.now(),
      updatedAt: DateTime.tryParse(updatedAtStr) ?? DateTime.now(),
      errorMessage: map['error_message']?.toString(),
    );
  }

  ScanSession copyWith({
    int? id,
    String? status,
    String? source,
    int? pageCount,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? errorMessage,
  }) {
    return ScanSession(
      id: id ?? this.id,
      status: status ?? this.status,
      source: source ?? this.source,
      pageCount: pageCount ?? this.pageCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}
