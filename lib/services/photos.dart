import 'dart:typed_data';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart' show compute;
import 'package:image/image.dart' as image;

/// Shared by all three upload paths: real JPEG, <=1440px, quality 78, <=2MB.
Uint8List preparePhoto(Uint8List bytes) {
  image.Image? decoded;
  try {
    decoded = image.decodeImage(bytes);
  } catch (_) {
    throw FirebaseFunctionsException(code: 'invalid-argument', message: 'Choose a readable photo.');
  }
  if (decoded == null) {
    throw FirebaseFunctionsException(code: 'invalid-argument', message: 'Choose a readable photo.');
  }
  decoded = image.bakeOrientation(decoded);
  if (decoded.width > 1440 || decoded.height > 1440) {
    decoded = decoded.width >= decoded.height ? image.copyResize(decoded, width: 1440) : image.copyResize(decoded, height: 1440);
  }
  // Bake orientation first, then discard camera/GPS EXIF before public uploads.
  decoded.exif.clear();
  final jpeg = image.encodeJpg(decoded, quality: 78);
  if (jpeg.length > 2 * 1024 * 1024) {
    throw FirebaseFunctionsException(code: 'invalid-argument', message: 'That photo is too large. Choose a smaller photo.');
  }
  return jpeg;
}

Future<Uint8List> photoForUpload(Uint8List bytes) => compute(preparePhoto, bytes);
