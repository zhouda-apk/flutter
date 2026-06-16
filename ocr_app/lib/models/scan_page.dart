class ScanPage {
  final int? id;
  final int sessionId;
  final int pageIndex;
  final String originalImagePath;
  final String processedImagePath;
  final String preprocessProfile;
  final String rawOcrText;
  final String cleanedOcrText;
  final double averageConfidence;
  final int lowConfidenceCount;
  final String metadataJson;

  const ScanPage({
    this.id,
    required this.sessionId,
    required this.pageIndex,
    required this.originalImagePath,
    required this.processedImagePath,
    required this.preprocessProfile,
    required this.rawOcrText,
    required this.cleanedOcrText,
    required this.averageConfidence,
    required this.lowConfidenceCount,
    this.metadataJson = '{}',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'session_id': sessionId,
      'page_index': pageIndex,
      'original_image_path': originalImagePath,
      'processed_image_path': processedImagePath,
      'preprocess_profile': preprocessProfile,
      'raw_ocr_text': rawOcrText,
      'cleaned_ocr_text': cleanedOcrText,
      'average_confidence': averageConfidence,
      'low_confidence_count': lowConfidenceCount,
      'metadata_json': metadataJson,
    };
  }

  factory ScanPage.fromMap(Map<String, dynamic> map) {
    return ScanPage(
      id: map['id'] is int ? map['id'] as int : int.tryParse('${map['id']}'),
      sessionId: map['session_id'] is int
          ? map['session_id'] as int
          : int.tryParse('${map['session_id']}') ?? 0,
      pageIndex: map['page_index'] is int
          ? map['page_index'] as int
          : int.tryParse('${map['page_index']}') ?? 0,
      originalImagePath: (map['original_image_path'] ?? '').toString(),
      processedImagePath: (map['processed_image_path'] ?? '').toString(),
      preprocessProfile: (map['preprocess_profile'] ?? '').toString(),
      rawOcrText: (map['raw_ocr_text'] ?? '').toString(),
      cleanedOcrText: (map['cleaned_ocr_text'] ?? '').toString(),
      averageConfidence: map['average_confidence'] is num
          ? (map['average_confidence'] as num).toDouble()
          : double.tryParse('${map['average_confidence']}') ?? 0.0,
      lowConfidenceCount: map['low_confidence_count'] is int
          ? map['low_confidence_count'] as int
          : int.tryParse('${map['low_confidence_count']}') ?? 0,
      metadataJson: (map['metadata_json'] ?? '{}').toString(),
    );
  }

  ScanPage copyWith({
    int? id,
    int? sessionId,
    int? pageIndex,
    String? originalImagePath,
    String? processedImagePath,
    String? preprocessProfile,
    String? rawOcrText,
    String? cleanedOcrText,
    double? averageConfidence,
    int? lowConfidenceCount,
    String? metadataJson,
  }) {
    return ScanPage(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      pageIndex: pageIndex ?? this.pageIndex,
      originalImagePath: originalImagePath ?? this.originalImagePath,
      processedImagePath: processedImagePath ?? this.processedImagePath,
      preprocessProfile: preprocessProfile ?? this.preprocessProfile,
      rawOcrText: rawOcrText ?? this.rawOcrText,
      cleanedOcrText: cleanedOcrText ?? this.cleanedOcrText,
      averageConfidence: averageConfidence ?? this.averageConfidence,
      lowConfidenceCount: lowConfidenceCount ?? this.lowConfidenceCount,
      metadataJson: metadataJson ?? this.metadataJson,
    );
  }
}
