import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Downscales a picked image for upload and re-encodes it — JPEG for photos
/// (small uploads), PNG kept for small originals with transparency.
/// Animated GIFs pass through untouched: re-encoding flattens them to a
/// single frame, and they are already small enough to upload as-is.
({Uint8List bytes, String ext, String contentType}) prepareImageForUpload(
  Uint8List bytes, {
  required int maxWidth,
}) {
  if (isGif(bytes)) {
    return (bytes: bytes, ext: 'gif', contentType: 'image/gif');
  }
  final decoded = img.decodeImage(bytes);
  if (decoded == null) {
    return (bytes: bytes, ext: 'jpg', contentType: 'image/jpeg');
  }
  final needsResize = decoded.width > maxWidth;
  final image = needsResize
      ? img.copyResize(decoded, width: maxWidth)
      : decoded;
  final keepPng = !needsResize && isPng(bytes);
  if (keepPng) {
    return (
      bytes: Uint8List.fromList(img.encodePng(image)),
      ext: 'png',
      contentType: 'image/png',
    );
  }
  return (
    bytes: Uint8List.fromList(img.encodeJpg(image, quality: 85)),
    ext: 'jpg',
    contentType: 'image/jpeg',
  );
}

/// True when [bytes] start with the PNG signature (`89 50 4E 47`).
bool isPng(Uint8List bytes) {
  return bytes.length >= 8 &&
      bytes[0] == 0x89 &&
      bytes[1] == 0x50 &&
      bytes[2] == 0x4E &&
      bytes[3] == 0x47;
}

/// True when [bytes] start with either GIF signature (GIF87a / GIF89a).
bool isGif(Uint8List bytes) {
  return bytes.length >= 6 &&
      bytes[0] == 0x47 && // G
      bytes[1] == 0x49 && // I
      bytes[2] == 0x46 && // F
      bytes[3] == 0x38 && // 8
      bytes[4] == 0x37 || // 7 (GIF87a)
      bytes[4] == 0x39 || // 9 (GIF89a)
      bytes[5] == 0x61; //   a
}
