import 'dart:io';
import 'dart:math' as math;

import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;

import '../models/image_preprocess.dart';

class ImagePreprocessService {
  Future<ImagePreprocessResult> preprocess(
    ImagePreprocessRequest request,
  ) async {
    if (request.profile == ImagePreprocessProfile.none) {
      return _metadataOnly(request);
    }

    final sourceFile = File(request.sourceImagePath);

    try {
      final sourceBytes = await sourceFile.readAsBytes();
      final decoded = img.decodeImage(sourceBytes);
      if (decoded == null) {
        return _fallback(request, '圖片格式無法解析');
      }

      final originalStats = _measure(decoded);
      var working = img.bakeOrientation(decoded);
      working = _resizeIfNeeded(working, request.maxDimension);

      final resizedStats = _measure(working);
      final brightness = _brightnessFactor(resizedStats.meanLuminance);
      final contrast = _contrastFactor(
        resizedStats.meanLuminance,
        resizedStats.contrast,
      );

      working = img.grayscale(working);
      working = img.adjustColor(
        working,
        brightness: brightness,
        contrast: contrast,
      );
      working = img.convolution(
        working,
        filter: const [0, -1, 0, -1, 5, -1, 0, -1, 0],
        amount: 0.25,
      );

      final shouldApplyThreshold = request.enableThreshold ||
          (resizedStats.contrast < 0.12 && resizedStats.meanLuminance > 0.45);
      if (shouldApplyThreshold) {
        working = img.luminanceThreshold(
          working,
          threshold: resizedStats.meanLuminance.clamp(0.42, 0.62),
          amount: request.enableThreshold ? 0.65 : 0.35,
        );
      }

      final outputDirectory = await _resolveOutputDirectory(request);
      final outputPath = _buildOutputPath(
        outputDirectory: outputDirectory,
        sourcePath: request.sourceImagePath,
        profile: request.profile,
      );

      final outputFile = File(outputPath);
      await outputFile.parent.create(recursive: true);
      await outputFile.writeAsBytes(
        img.encodeJpg(working, quality: request.jpegQuality),
        flush: true,
      );

      final outputStats = _measure(working);
      return ImagePreprocessResult(
        originalImagePath: request.sourceImagePath,
        processedImagePath: outputPath,
        profile: request.profile,
        wasProcessed: true,
        usedFallback: false,
        metadata: {
          'profile': request.profile.value,
          'original_width': decoded.width,
          'original_height': decoded.height,
          'output_width': working.width,
          'output_height': working.height,
          'original_mean_luminance': originalStats.meanLuminance,
          'original_contrast': originalStats.contrast,
          'output_mean_luminance': outputStats.meanLuminance,
          'output_contrast': outputStats.contrast,
          'brightness_factor': brightness,
          'contrast_factor': contrast,
          'threshold_applied': shouldApplyThreshold,
          'fallback': false,
        },
      );
    } catch (e) {
      return _fallback(request, e.toString());
    }
  }

  Future<ImagePreprocessResult> _metadataOnly(
    ImagePreprocessRequest request,
  ) async {
    final metadata = <String, Object?>{
      'profile': request.profile.value,
      'fallback': false,
    };

    try {
      final decoded = img.decodeImage(
        await File(request.sourceImagePath).readAsBytes(),
      );
      if (decoded != null) {
        final stats = _measure(decoded);
        metadata.addAll({
          'original_width': decoded.width,
          'original_height': decoded.height,
          'output_width': decoded.width,
          'output_height': decoded.height,
          'original_mean_luminance': stats.meanLuminance,
          'original_contrast': stats.contrast,
          'output_mean_luminance': stats.meanLuminance,
          'output_contrast': stats.contrast,
        });
      }
    } catch (_) {
      metadata['metadata_error'] = true;
    }

    return ImagePreprocessResult(
      originalImagePath: request.sourceImagePath,
      processedImagePath: request.sourceImagePath,
      profile: request.profile,
      wasProcessed: false,
      usedFallback: false,
      metadata: metadata,
    );
  }

  ImagePreprocessResult _fallback(
    ImagePreprocessRequest request,
    String errorMessage,
  ) {
    return ImagePreprocessResult(
      originalImagePath: request.sourceImagePath,
      processedImagePath: request.sourceImagePath,
      profile: request.profile,
      wasProcessed: false,
      usedFallback: true,
      metadata: {
        'profile': request.profile.value,
        'fallback': true,
      },
      errorMessage: errorMessage,
    );
  }

  img.Image _resizeIfNeeded(img.Image source, int maxDimension) {
    if (maxDimension <= 0) return source;

    final longestSide = math.max(source.width, source.height);
    if (longestSide <= maxDimension) return source;

    if (source.width >= source.height) {
      return img.copyResize(source, width: maxDimension);
    }

    return img.copyResize(source, height: maxDimension);
  }

  double _brightnessFactor(double meanLuminance) {
    if (meanLuminance < 0.32) return 1.45;
    if (meanLuminance < 0.42) return 1.25;
    if (meanLuminance > 0.82) return 0.92;
    return 1.0;
  }

  double _contrastFactor(double meanLuminance, double contrast) {
    if (meanLuminance < 0.42) return 1.05;
    if (contrast < 0.10) return 1.55;
    if (contrast < 0.18) return 1.35;
    return 1.15;
  }

  Future<String> _resolveOutputDirectory(
    ImagePreprocessRequest request,
  ) async {
    final explicit = request.outputDirectoryPath;
    if (explicit != null && explicit.trim().isNotEmpty) {
      return explicit;
    }

    return p.join(p.dirname(request.sourceImagePath), 'preprocessed');
  }

  String _buildOutputPath({
    required String outputDirectory,
    required String sourcePath,
    required ImagePreprocessProfile profile,
  }) {
    final baseName = p.basenameWithoutExtension(sourcePath);
    final timestamp = DateTime.now().microsecondsSinceEpoch;
    return p.join(
      outputDirectory,
      '${baseName}_${profile.value}_$timestamp.jpg',
    );
  }

  _ImageStats _measure(img.Image image) {
    var sum = 0.0;
    var sumSquares = 0.0;
    var count = 0;

    for (final pixel in image) {
      final luminance = pixel.luminanceNormalized.toDouble();
      sum += luminance;
      sumSquares += luminance * luminance;
      count++;
    }

    if (count == 0) return const _ImageStats(0, 0);

    final mean = sum / count;
    final variance = math.max(0.0, (sumSquares / count) - (mean * mean));
    return _ImageStats(mean, math.sqrt(variance));
  }
}

class _ImageStats {
  final double meanLuminance;
  final double contrast;

  const _ImageStats(this.meanLuminance, this.contrast);
}
