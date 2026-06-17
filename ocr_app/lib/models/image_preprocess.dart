enum ImagePreprocessProfile {
  none('none'),
  autoDocument('auto_document');

  const ImagePreprocessProfile(this.value);

  final String value;
}

class ImagePreprocessRequest {
  final String sourceImagePath;
  final ImagePreprocessProfile profile;
  final String? outputDirectoryPath;
  final int maxDimension;
  final int jpegQuality;
  final bool enableThreshold;

  const ImagePreprocessRequest({
    required this.sourceImagePath,
    this.profile = ImagePreprocessProfile.autoDocument,
    this.outputDirectoryPath,
    this.maxDimension = 1800,
    this.jpegQuality = 92,
    this.enableThreshold = false,
  });
}

class ImagePreprocessResult {
  final String originalImagePath;
  final String processedImagePath;
  final ImagePreprocessProfile profile;
  final bool wasProcessed;
  final bool usedFallback;
  final Map<String, Object?> metadata;
  final String? errorMessage;

  const ImagePreprocessResult({
    required this.originalImagePath,
    required this.processedImagePath,
    required this.profile,
    required this.wasProcessed,
    required this.usedFallback,
    required this.metadata,
    this.errorMessage,
  });

  bool get hasError => errorMessage != null && errorMessage!.isNotEmpty;
}
