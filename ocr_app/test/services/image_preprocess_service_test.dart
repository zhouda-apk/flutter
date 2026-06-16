import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;

import 'package:ocr_notes_app/models/image_preprocess.dart';
import 'package:ocr_notes_app/services/image_preprocess_service.dart';

import '../fixtures/scan_image_fixtures.dart';

void main() {
  late Directory tempDir;
  late ImagePreprocessService service;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('ocr_preprocess_test_');
    service = ImagePreprocessService();
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('none profile returns original path without creating processed file',
      () async {
    final sourcePath = p.join(tempDir.path, 'source.jpg');
    await _writeTestImage(sourcePath, width: 80, height: 40, value: 180);

    final result = await service.preprocess(
      ImagePreprocessRequest(
        sourceImagePath: sourcePath,
        profile: ImagePreprocessProfile.none,
      ),
    );

    expect(result.originalImagePath, sourcePath);
    expect(result.processedImagePath, sourcePath);
    expect(result.wasProcessed, isFalse);
    expect(result.usedFallback, isFalse);
    expect(result.metadata['profile'], 'none');
    expect(result.metadata['original_width'], 80);
    expect(result.metadata['original_height'], 40);
  });

  test('autoDocument writes a separate processed image with metadata',
      () async {
    final sourcePath = p.join(tempDir.path, 'dark_source.jpg');
    final outputDir = p.join(tempDir.path, 'processed');
    await _writeTestImage(sourcePath, width: 200, height: 100, value: 48);

    final result = await service.preprocess(
      ImagePreprocessRequest(
        sourceImagePath: sourcePath,
        outputDirectoryPath: outputDir,
        maxDimension: 120,
      ),
    );

    expect(result.originalImagePath, sourcePath);
    expect(result.processedImagePath, isNot(sourcePath));
    expect(result.processedImagePath, startsWith(outputDir));
    expect(result.processedImagePath, endsWith('.jpg'));
    expect(result.wasProcessed, isTrue);
    expect(result.usedFallback, isFalse);
    expect(File(result.processedImagePath).existsSync(), isTrue);
    expect(File(sourcePath).existsSync(), isTrue);

    expect(result.metadata['profile'], 'auto_document');
    expect(result.metadata['original_width'], 200);
    expect(result.metadata['original_height'], 100);
    expect(result.metadata['output_width'], 120);
    expect(result.metadata['output_height'], 60);
    expect(result.metadata['brightness_factor'], greaterThan(1.0));
    expect(result.metadata['fallback'], isFalse);

    final original = img.decodeImage(File(sourcePath).readAsBytesSync())!;
    final processed =
        img.decodeImage(File(result.processedImagePath).readAsBytesSync())!;
    expect(_meanLuminance(processed), greaterThan(_meanLuminance(original)));
  });

  test('processing failure falls back to original image path', () async {
    final sourcePath = p.join(tempDir.path, 'corrupt.jpg');
    await File(sourcePath).writeAsString('not an image');

    final result = await service.preprocess(
      ImagePreprocessRequest(sourceImagePath: sourcePath),
    );

    expect(result.processedImagePath, sourcePath);
    expect(result.wasProcessed, isFalse);
    expect(result.usedFallback, isTrue);
    expect(result.hasError, isTrue);
    expect(result.metadata['fallback'], isTrue);
  });

  test('fixture image set preprocesses common capture conditions', () async {
    final fixtures = await createScanImageFixtureSet(tempDir);
    expect(fixtures, hasLength(7));

    for (final fixture in fixtures) {
      final result = await service.preprocess(
        ImagePreprocessRequest(
          sourceImagePath: fixture.path,
          outputDirectoryPath: p.join(tempDir.path, 'processed'),
          maxDimension: 720,
        ),
      );

      expect(result.wasProcessed, isTrue, reason: fixture.kind.name);
      expect(result.usedFallback, isFalse, reason: fixture.kind.name);
      expect(File(result.processedImagePath).existsSync(), isTrue);
      expect(result.metadata['output_width'], isA<int>());
      expect(result.metadata['output_height'], isA<int>());
      expect(
        result.metadata['output_contrast'],
        greaterThanOrEqualTo(result.metadata['original_contrast'] as double),
        reason: fixture.kind.name,
      );
    }
  });

  test('large image is resized to max dimension for memory safety', () async {
    final sourcePath = p.join(tempDir.path, 'large.jpg');
    await _writeTestImage(sourcePath, width: 2600, height: 1800, value: 120);

    final result = await service.preprocess(
      ImagePreprocessRequest(
        sourceImagePath: sourcePath,
        outputDirectoryPath: p.join(tempDir.path, 'processed'),
        maxDimension: 900,
      ),
    );

    expect(result.wasProcessed, isTrue);
    expect(result.usedFallback, isFalse);
    expect(result.metadata['original_width'], 2600);
    expect(result.metadata['original_height'], 1800);
    expect(result.metadata['output_width'], 900);
    expect(result.metadata['output_height'], lessThanOrEqualTo(900));
  });
}

Future<void> _writeTestImage(
  String path, {
  required int width,
  required int height,
  required int value,
}) async {
  final image = img.Image(width: width, height: height);
  img.fill(image, color: img.ColorRgb8(value, value, value));
  await File(path).writeAsBytes(img.encodeJpg(image, quality: 95));
}

double _meanLuminance(img.Image image) {
  var sum = 0.0;
  var count = 0;
  for (final pixel in image) {
    sum += pixel.luminanceNormalized.toDouble();
    count++;
  }
  return sum / count;
}
