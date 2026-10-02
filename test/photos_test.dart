import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;
import 'package:cloud_functions/cloud_functions.dart';
import 'package:rakta_bandhan/services/photos.dart';

void main() {
  test('PNG input becomes a bounded JPEG without distorting its aspect ratio', () {
    final encoded = preparePhoto(image.encodePng(image.Image(width: 1600, height: 800)));
    expect(encoded.take(3), [255, 216, 255]);
    final decoded = image.decodeJpg(encoded)!;
    expect(decoded.width, 1440);
    expect(decoded.height, 720);
    expect(encoded.length, lessThanOrEqualTo(2 * 1024 * 1024));
    expect(() => preparePhoto(Uint8List.fromList([1, 2, 3])), throwsA(isA<FirebaseFunctionsException>()));
  });
}
