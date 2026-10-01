import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gm;

import '../theme/app_colors.dart';

/// Donor pins for the native Google map, drawn to match the flutter_map
/// pins: a disc showing the blood group, white ring, and a short tail whose
/// tip is the donor's position. Painted once per style and cached.
abstract final class DonorMarkerIcons {
  static final _cache = <String, gm.BitmapDescriptor>{};

  /// A ready icon, or null while it's still being painted (the caller then
  /// shows the default marker and asks again after [warm] completes).
  static gm.BitmapDescriptor? peek(String group, {required bool primary, required bool highlighted}) =>
      _cache[_key(group, primary, highlighted)];

  static String _key(String group, bool primary, bool highlighted) => '$group|$primary|$highlighted';

  static Future<void> warm(String group, {required bool primary, required bool highlighted, required double pixelRatio}) async {
    final key = _key(group, primary, highlighted);
    if (_cache.containsKey(key)) return;
    _cache[key] = await _paint(group, primary: primary, highlighted: highlighted, pixelRatio: pixelRatio);
  }

  static Future<gm.BitmapDescriptor> _paint(String group, {required bool primary, required bool highlighted, required double pixelRatio}) async {
    final disc = primary ? 52.0 : 42.0;
    const tail = 12.0;
    final width = disc + 8;
    final height = disc + tail + 8;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)..scale(pixelRatio);
    final centre = Offset(width / 2, disc / 2 + 4);
    final fill = primary ? AppColors.primary : AppColors.primaryLightTint;

    // Soft shadow, tail, disc, ring.
    canvas.drawCircle(centre.translate(0, 3), disc / 2, Paint()..color = Colors.black26..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
    final tailPath = Path()
      ..moveTo(centre.dx - 7, centre.dy + disc / 2 - 4)
      ..lineTo(centre.dx, centre.dy + disc / 2 + tail)
      ..lineTo(centre.dx + 7, centre.dy + disc / 2 - 4)
      ..close();
    canvas.drawPath(tailPath, Paint()..color = fill);
    canvas.drawCircle(centre, disc / 2, Paint()..color = fill);
    canvas.drawCircle(
      centre,
      disc / 2,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = highlighted ? 3.5 : 2.5
        ..color = highlighted ? AppColors.ink : Colors.white,
    );

    final text = TextPainter(
      text: TextSpan(
        text: group,
        style: TextStyle(fontSize: primary ? 16 : 13, fontWeight: FontWeight.w700, color: primary ? Colors.white : AppColors.primary),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    text.paint(canvas, centre - Offset(text.width / 2, text.height / 2));

    final image = await recorder.endRecording().toImage((width * pixelRatio).ceil(), (height * pixelRatio).ceil());
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return gm.BitmapDescriptor.bytes(bytes!.buffer.asUint8List(), imagePixelRatio: pixelRatio);
  }
}
