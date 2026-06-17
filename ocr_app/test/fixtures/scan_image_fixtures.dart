import 'dart:io';
import 'dart:math' as math;

import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;

enum ScanFixtureKind {
  clear,
  lowLight,
  glare,
  lowContrast,
  slightSkew,
  multiPage,
}

class ScanImageFixture {
  final ScanFixtureKind kind;
  final String path;

  const ScanImageFixture({
    required this.kind,
    required this.path,
  });
}

Future<List<ScanImageFixture>> createScanImageFixtureSet(
  Directory directory,
) async {
  final fixtures = <ScanImageFixture>[];
  for (final kind in ScanFixtureKind.values) {
    final pageCount = kind == ScanFixtureKind.multiPage ? 2 : 1;
    for (var page = 0; page < pageCount; page++) {
      final image = _documentImage(kind: kind, page: page);
      final path = p.join(directory.path, '${kind.name}_$page.jpg');
      await File(path).writeAsBytes(img.encodeJpg(image, quality: 92));
      fixtures.add(ScanImageFixture(kind: kind, path: path));
    }
  }
  return fixtures;
}

img.Image _documentImage({
  required ScanFixtureKind kind,
  required int page,
}) {
  var image = img.Image(width: 640, height: 900);
  final background = switch (kind) {
    ScanFixtureKind.lowLight => 46,
    ScanFixtureKind.lowContrast => 210,
    _ => 246,
  };
  final ink = switch (kind) {
    ScanFixtureKind.lowLight => 172,
    ScanFixtureKind.lowContrast => 150,
    _ => 42,
  };

  img.fill(image, color: img.ColorRgb8(background, background, background));
  img.fillRect(
    image,
    x1: 48,
    y1: 54,
    x2: 592,
    y2: 846,
    color: img.ColorRgb8(
      math.min(255, background + 8),
      math.min(255, background + 8),
      math.min(255, background + 8),
    ),
  );

  for (var i = 0; i < 11; i++) {
    final y = 150 + i * 48;
    final lineWidth = i.isEven ? 410 : 330;
    img.fillRect(
      image,
      x1: 92,
      y1: y,
      x2: 92 + lineWidth,
      y2: y + 12,
      color: img.ColorRgb8(ink, ink, ink),
    );
  }
  img.fillRect(
    image,
    x1: 92,
    y1: 92,
    x2: 360 + page * 40,
    y2: 118,
    color: img.ColorRgb8(ink, ink, ink),
  );

  if (kind == ScanFixtureKind.glare) {
    for (var radius = 0; radius < 160; radius += 2) {
      final alpha = (180 - radius).clamp(0, 155);
      img.drawCircle(
        image,
        x: 430,
        y: 220,
        radius: radius,
        color: img.ColorRgba8(255, 255, 255, alpha),
      );
    }
  }

  if (kind == ScanFixtureKind.slightSkew) {
    image.backgroundColor = img.ColorRgb8(238, 238, 238);
    image = img.copyRotate(image, angle: -4);
  }

  return image;
}
