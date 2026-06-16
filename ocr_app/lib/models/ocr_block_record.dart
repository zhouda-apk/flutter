class OcrBlockRecord {
  final int? id;
  final int pageId;
  final int blockIndex;
  final String text;
  final double confidence;
  final String boundingBoxJson;
  final bool isLowConfidence;

  const OcrBlockRecord({
    this.id,
    required this.pageId,
    required this.blockIndex,
    required this.text,
    required this.confidence,
    this.boundingBoxJson = '{}',
    required this.isLowConfidence,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'page_id': pageId,
      'block_index': blockIndex,
      'text': text,
      'confidence': confidence,
      'bounding_box_json': boundingBoxJson,
      'is_low_confidence': isLowConfidence ? 1 : 0,
    };
  }

  factory OcrBlockRecord.fromMap(Map<String, dynamic> map) {
    return OcrBlockRecord(
      id: map['id'] is int ? map['id'] as int : int.tryParse('${map['id']}'),
      pageId: map['page_id'] is int
          ? map['page_id'] as int
          : int.tryParse('${map['page_id']}') ?? 0,
      blockIndex: map['block_index'] is int
          ? map['block_index'] as int
          : int.tryParse('${map['block_index']}') ?? 0,
      text: (map['text'] ?? '').toString(),
      confidence: map['confidence'] is num
          ? (map['confidence'] as num).toDouble()
          : double.tryParse('${map['confidence']}') ?? 0.0,
      boundingBoxJson: (map['bounding_box_json'] ?? '{}').toString(),
      isLowConfidence: map['is_low_confidence'] == 1 ||
          map['is_low_confidence'] == true ||
          '${map['is_low_confidence']}' == 'true',
    );
  }

  OcrBlockRecord copyWith({
    int? id,
    int? pageId,
    int? blockIndex,
    String? text,
    double? confidence,
    String? boundingBoxJson,
    bool? isLowConfidence,
  }) {
    return OcrBlockRecord(
      id: id ?? this.id,
      pageId: pageId ?? this.pageId,
      blockIndex: blockIndex ?? this.blockIndex,
      text: text ?? this.text,
      confidence: confidence ?? this.confidence,
      boundingBoxJson: boundingBoxJson ?? this.boundingBoxJson,
      isLowConfidence: isLowConfidence ?? this.isLowConfidence,
    );
  }
}
