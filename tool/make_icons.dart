// Regenerates every site icon from one source image.
//
// The site's icon identity lives in a single place — assets/Nisk-Fav.png —
// and this tool fans it out into every size and shape the web needs:
//
//   web/favicon.png                  — the classic favicon file
//   web/icons/Icon-192.png           — PWA / bookmark icon
//   web/icons/Icon-512.png           — PWA / splash icon
//   web/icons/Icon-maskable-192.png  — Android adaptive (circle-cropped)
//   web/icons/Icon-maskable-512.png  — Android adaptive (circle-cropped)
//
// Maskable icons get cropped to a circle by Android, so they are composed
// at 80% size on a black canvas — the identity sits safely inside the crop.
//
// Usage: dart run tool/make_icons.dart
// (Run from the project root. Safe to re-run any time the source changes.)
//
// ignore_for_file: avoid_print — a build tool talks through stdout.

import 'dart:io';

import 'package:image/image.dart' as img;

void main() {
  final bytes = File('assets/Nisk-Fav.png').readAsBytesSync();
  final decoded = img.decodePng(bytes);
  if (decoded == null) {
    stderr.writeln('assets/Nisk-Fav.png is not a valid PNG.');
    exit(1);
  }

  // Icons are square; center-crop the source so any aspect works.
  final square = _centerSquare(decoded);

  void write(img.Image image, String path) {
    File(path).writeAsBytesSync(img.encodePng(image));
    print('  $path  (${image.width}x${image.height})');
  }

  print('Generating site icons from assets/Nisk-Fav.png '
      '(${decoded.width}x${decoded.height})...');

  // Straight resizes for the classic favicon and the plain PWA icons.
  write(img.copyResize(square, width: 64), 'web/favicon.png');
  write(img.copyResize(square, width: 192), 'web/icons/Icon-192.png');
  write(img.copyResize(square, width: 512), 'web/icons/Icon-512.png');

  // Maskable variants: the identity at 80% on a black canvas, centered —
  // Android crops a circle from the canvas and nothing important is lost.
  write(_maskable(square, 192), 'web/icons/Icon-maskable-192.png');
  write(_maskable(square, 512), 'web/icons/Icon-maskable-512.png');

  print('Done — all site icons now wear the Nisk-Fav face.');
}

/// Center-crops [image] to a square (the largest square that fits).
img.Image _centerSquare(img.Image image) {
  if (image.width == image.height) return image;
  final side = image.width < image.height ? image.width : image.height;
  final x = (image.width - side) ~/ 2;
  final y = (image.height - side) ~/ 2;
  return img.copyCrop(
    image,
    x: x,
    y: y,
    width: side,
    height: side,
  );
}

/// The identity scaled to [size] * 80%, centered on a black [size]x[size]
/// canvas (the site's pure-black theme carries into the cropped edges).
img.Image _maskable(img.Image square, int size) {
  final inner = img.copyResize(square, width: (size * 0.8).round());
  final canvas = img.Image(width: size, height: size);
  img.fill(canvas, color: img.ColorRgba8(0, 0, 0, 255));
  img.compositeImage(
    canvas,
    inner,
    dstX: (size - inner.width) ~/ 2,
    dstY: (size - inner.height) ~/ 2,
  );
  return canvas;
}
