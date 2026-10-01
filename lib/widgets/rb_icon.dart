import 'package:flutter/material.dart';

/// The Rakta Bandhan icon family — drawn here, not taken from an icon font.
///
/// One construction rule for every glyph, so they read as a set:
/// - a 24-unit grid, drawn as a single monoline at 1.9 units (a touch
///   heavier than typical outline sets, so it holds up at small sizes);
/// - round caps and joins everywhere;
/// - soft, slightly asymmetric curves instead of geometric primitives —
///   the phone, bubble and shield are drawn by hand, not from circles and
///   rectangles;
/// - the brand's droplet recurs as a motif (request, history, certificate,
///   privacy shield) so the set belongs to a blood-donation product.
///
/// Every user-facing screen uses this family; lucide_icons_flutter remains
/// only in the unreachable in-app admin screens.
///
/// Size and colour follow [IconTheme] when not given, so an [RbIcon] drops
/// into buttons exactly where an [Icon] would.
enum RbGlyph {
  droplet,
  find,
  pin,
  community,
  person,
  history,
  certificate,
  phone,
  phoneHeart,
  message,
  shield,
  lock,
  page,
  bell,
  more,
  route,
  home,
  close,
  plus,
  chevron,
  back,
  check,
  checkCircle,
  clock,
  search,
  info,
  send,
  eye,
  logout,
  offline,
  pen,
  locate,
  closeCircle,
  alertCircle,
  mobile,
  minus,
  hourglass,
  flag,
  building,
  alert,
  quote,
  hangUp,
  megaphone,
  photo,
  photoAdd,
  photoOff,
  camera,
  connect,
  flame,
  clipboard,
  chevronDown,
  verified,
  forward,
  speaker,
  retry,
  phoneMissed,
  mic,
  micOff,
  inbox,
  heart,
  globe,
  pageClock,
  eyeOff,
  copy,
  calendar,
  trash,
  mail,
  bellOff,
  share,
  download,
  settings,
  idCard,
  radar,
}

class RbIcon extends StatelessWidget {
  final RbGlyph glyph;
  final double? size;
  final Color? color;
  final String? semanticLabel;

  /// Colour of the soft duotone fill behind the glyph's main form. Defaults
  /// to the line colour at low opacity; pass [Colors.transparent] for a
  /// pure line (e.g. inside a filled button).
  final Color? accent;

  const RbIcon(this.glyph, {super.key, this.size, this.color, this.semanticLabel, this.accent});

  @override
  Widget build(BuildContext context) {
    final theme = IconTheme.of(context);
    final s = size ?? theme.size ?? 24;
    final c = color ?? theme.color ?? const Color(0xFF241413);
    // Center (factor 1) keeps the glyph at its own size when a parent forces
    // a bigger box — e.g. InputDecoration.prefixIcon's 48px slot — instead of
    // the painter scaling up to fill it; under loose constraints it still
    // shrink-wraps to s×s.
    final painted = Center(
      widthFactor: 1,
      heightFactor: 1,
      child: SizedBox(
        width: s,
        height: s,
        child: CustomPaint(painter: _RbIconPainter(glyph, c, accent ?? c.withValues(alpha: 0.24))),
      ),
    );
    return semanticLabel == null ? ExcludeSemantics(child: painted) : Semantics(label: semanticLabel, child: painted);
  }
}

class _RbIconPainter extends CustomPainter {
  final RbGlyph glyph;
  final Color color;
  final Color accent;
  _RbIconPainter(this.glyph, this.color, this.accent);

  static const _stroke = 1.9;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 24, size.height / 24);
    final line = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = _stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final fill = Paint()..color = color;

    // The duotone layer: the glyph's main form filled in a soft tint and
    // printed slightly off-register (down-right), like a two-colour print —
    // the detail that makes the set feel drawn rather than library-stock.
    final accents = _accents(glyph);
    if (accents.isNotEmpty && accent.a > 0) {
      canvas.save();
      canvas.translate(1.5, 1.3);
      final tint = Paint()..color = accent;
      for (final a in accents) {
        canvas.drawPath(a, tint);
      }
      canvas.restore();
    }

    for (final p in _paths(glyph)) {
      canvas.drawPath(p, line);
    }
    for (final (c, r) in _dots(glyph)) {
      canvas.drawCircle(c, r, fill);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _RbIconPainter old) => old.glyph != glyph || old.color != color || old.accent != accent;

  // A droplet with a slightly fuller left belly — the brand mark's shape.
  static Path _drop(double cx, double top, double w, double h) {
    final bottom = top + h;
    final r = w / 2;
    return Path()
      ..moveTo(cx, top)
      ..cubicTo(cx - r * 0.35, top + h * 0.28, cx - r * 1.02, top + h * 0.46, cx - r, bottom - r)
      ..arcToPoint(Offset(cx + r, bottom - r), radius: Radius.circular(r), clockwise: false)
      ..cubicTo(cx + r * 0.98, top + h * 0.48, cx + r * 0.3, top + h * 0.26, cx, top)
      ..close();
  }

  static Path _circle(double cx, double cy, double r) => Path()..addOval(Rect.fromCircle(center: Offset(cx, cy), radius: r));

  static List<Path> _paths(RbGlyph g) {
    switch (g) {
      case RbGlyph.droplet:
        return [
          _drop(12, 2.6, 13.2, 18.8),
          // Highlight stroke inside the droplet — the one bit of "shine".
          Path()
            ..moveTo(8.9, 14.6)
            ..quadraticBezierTo(9.3, 17.1, 11.6, 17.9),
        ];
      case RbGlyph.pin:
        return [
          Path()
            ..moveTo(12, 21)
            ..cubicTo(9.4, 18.4, 5.4, 14.2, 5.4, 10.2)
            ..cubicTo(5.4, 6.4, 8.4, 3.6, 12, 3.6)
            ..cubicTo(15.6, 3.6, 18.6, 6.4, 18.6, 10.2)
            ..cubicTo(18.6, 14.2, 14.6, 18.4, 12, 21),
          _circle(12, 10.1, 2.4),
        ];
      case RbGlyph.find:
        // The location pin with two soft "looking nearby" arcs beside it.
        return [
          Path()
            ..moveTo(11, 20.4)
            ..cubicTo(8.8, 18.1, 5.6, 14.6, 5.6, 11.2)
            ..cubicTo(5.6, 8, 8.1, 5.6, 11, 5.6)
            ..cubicTo(13.9, 5.6, 16.4, 8, 16.4, 11.2)
            ..cubicTo(16.4, 14.6, 13.2, 18.1, 11, 20.4),
          _circle(11, 11.1, 2),
          Path()
            ..moveTo(17.2, 3.6)
            ..quadraticBezierTo(19.9, 4.6, 20.8, 7.4),
          Path()
            ..moveTo(16.9, 6.6)
            ..quadraticBezierTo(18, 7.1, 18.4, 8.3),
        ];
      case RbGlyph.community:
        // Two people, one a little behind the other.
        return [
          _circle(9, 8.2, 3.1),
          Path()
            ..moveTo(3.4, 19.6)
            ..cubicTo(3.9, 15.8, 6.2, 13.8, 9, 13.8)
            ..cubicTo(11.8, 13.8, 14.1, 15.8, 14.6, 19.6),
          Path()
            ..moveTo(14.4, 5.5)
            ..cubicTo(15.9, 5.1, 17.9, 6, 17.9, 8.2)
            ..cubicTo(17.9, 10.1, 16.4, 11.2, 15, 11.1),
          Path()
            ..moveTo(16.6, 13.9)
            ..cubicTo(18.9, 14.4, 20.4, 16.3, 20.7, 19.3),
        ];
      case RbGlyph.person:
        return [
          _circle(12, 8, 3.6),
          Path()
            ..moveTo(5, 20.2)
            ..cubicTo(5.7, 16.2, 8.5, 13.9, 12, 13.9)
            ..cubicTo(15.5, 13.9, 18.3, 16.2, 19, 20.2),
        ];
      case RbGlyph.history:
        // An open circle turning back on itself, a droplet at its centre.
        return [
          Path()
            ..moveTo(4.4, 12.6)
            ..cubicTo(4.6, 16.8, 8, 20, 12.2, 20)
            ..cubicTo(16.4, 20, 19.8, 16.5, 19.8, 12.2)
            ..cubicTo(19.8, 7.9, 16.4, 4.4, 12.1, 4.4)
            ..cubicTo(9.4, 4.4, 7.1, 5.8, 5.8, 7.9),
          Path()
            ..moveTo(5.4, 4.6)
            ..lineTo(5.7, 8.2)
            ..lineTo(9.2, 7.7),
          _drop(12.1, 8.6, 5, 7.4),
        ];
      case RbGlyph.certificate:
        // A rosette carrying the droplet, two ribbon tails.
        return [
          _circle(12, 9.3, 5.6),
          _drop(12, 6.1, 3.8, 5.6),
          Path()
            ..moveTo(8.9, 14)
            ..lineTo(7.7, 20.6)
            ..lineTo(10.2, 19.5)
            ..lineTo(11.4, 21.2),
          Path()
            ..moveTo(15.1, 14)
            ..lineTo(16.3, 20.6)
            ..lineTo(13.8, 19.5)
            ..lineTo(12.6, 21.2),
        ];
      case RbGlyph.phone:
        return [_handset()];
      case RbGlyph.phoneHeart:
        return [
          _handset(),
          Path()
            ..moveTo(17.2, 9.2)
            ..cubicTo(15.6, 8, 14.2, 6.8, 14.2, 5.4)
            ..cubicTo(14.2, 4.4, 15, 3.7, 15.8, 3.7)
            ..cubicTo(16.4, 3.7, 16.9, 4, 17.2, 4.5)
            ..cubicTo(17.5, 4, 18, 3.7, 18.6, 3.7)
            ..cubicTo(19.4, 3.7, 20.2, 4.4, 20.2, 5.4)
            ..cubicTo(20.2, 6.8, 18.8, 8, 17.2, 9.2),
        ];
      case RbGlyph.message:
        return [
          Path()
            ..moveTo(12, 4.6)
            ..cubicTo(16.3, 4.6, 19.6, 7.3, 19.6, 11.1)
            ..cubicTo(19.6, 14.9, 16.3, 17.6, 12, 17.6)
            ..cubicTo(11.1, 17.6, 10.2, 17.5, 9.4, 17.2)
            ..lineTo(5.4, 19.4)
            ..lineTo(6.3, 15.5)
            ..cubicTo(5, 14.3, 4.4, 12.8, 4.4, 11.1)
            ..cubicTo(4.4, 7.3, 7.7, 4.6, 12, 4.6),
          Path()
            ..moveTo(8.8, 11.2)
            ..lineTo(15.2, 11.2),
        ];
      case RbGlyph.shield:
        return [
          Path()
            ..moveTo(12, 3)
            ..cubicTo(9.8, 4.5, 7.4, 5.2, 4.9, 5.4)
            ..cubicTo(4.8, 12.3, 7.1, 17.6, 12, 21)
            ..cubicTo(16.9, 17.6, 19.2, 12.3, 19.1, 5.4)
            ..cubicTo(16.6, 5.2, 14.2, 4.5, 12, 3),
          _drop(12, 8.4, 4.6, 6.8),
        ];
      case RbGlyph.lock:
        return [
          Path()
            ..addRRect(RRect.fromRectAndRadius(const Rect.fromLTRB(5.2, 10.4, 18.8, 20.6), const Radius.circular(3.4))),
          Path()
            ..moveTo(8.2, 10.4)
            ..lineTo(8.2, 8.1)
            ..cubicTo(8.2, 5.9, 9.9, 4.2, 12, 4.2)
            ..cubicTo(14.1, 4.2, 15.8, 5.9, 15.8, 8.1)
            ..lineTo(15.8, 10.4),
          Path()
            ..moveTo(12, 14.4)
            ..lineTo(12, 16.4),
        ];
      case RbGlyph.page:
        return [
          Path()
            ..moveTo(14.2, 3.4)
            ..lineTo(7.4, 3.4)
            ..cubicTo(6.3, 3.4, 5.4, 4.3, 5.4, 5.4)
            ..lineTo(5.4, 18.6)
            ..cubicTo(5.4, 19.7, 6.3, 20.6, 7.4, 20.6)
            ..lineTo(16.6, 20.6)
            ..cubicTo(17.7, 20.6, 18.6, 19.7, 18.6, 18.6)
            ..lineTo(18.6, 7.8)
            ..close(),
          Path()
            ..moveTo(14, 3.6)
            ..lineTo(14, 6.6)
            ..cubicTo(14, 7.3, 14.5, 7.8, 15.2, 7.8)
            ..lineTo(18.4, 7.8),
          Path()
            ..moveTo(8.6, 12)
            ..lineTo(15.4, 12),
          Path()
            ..moveTo(8.6, 15.6)
            ..lineTo(12.8, 15.6),
        ];
      case RbGlyph.bell:
        return [
          Path()
            ..moveTo(5, 17.2)
            ..cubicTo(6.2, 16, 6.6, 14.6, 6.6, 12.8)
            ..lineTo(6.6, 10.6)
            ..cubicTo(6.6, 7.5, 9, 5, 12, 5)
            ..cubicTo(15, 5, 17.4, 7.5, 17.4, 10.6)
            ..lineTo(17.4, 12.8)
            ..cubicTo(17.4, 14.6, 17.8, 16, 19, 17.2)
            ..close(),
          Path()
            ..moveTo(10.2, 20)
            ..quadraticBezierTo(12, 21.4, 13.8, 20),
          Path()
            ..moveTo(12, 3.2)
            ..lineTo(12, 5),
        ];
      case RbGlyph.more:
        return const [];
      case RbGlyph.route:
        // From a start point along a winding path to a small pin.
        return [
          _circle(6, 18, 2),
          Path()
            ..moveTo(8.2, 18)
            ..lineTo(14.4, 18)
            ..cubicTo(16.1, 18, 17.4, 16.7, 17.4, 15)
            ..cubicTo(17.4, 13.3, 16.1, 12, 14.4, 12)
            ..lineTo(9.6, 12)
            ..cubicTo(7.9, 12, 6.6, 10.7, 6.6, 9)
            ..cubicTo(6.6, 7.3, 7.9, 6, 9.6, 6)
            ..lineTo(14.6, 6),
          Path()
            ..moveTo(18, 9.8)
            ..cubicTo(16.6, 8.4, 15.6, 7.2, 15.6, 5.8)
            ..cubicTo(15.6, 4.5, 16.7, 3.4, 18, 3.4)
            ..cubicTo(19.3, 3.4, 20.4, 4.5, 20.4, 5.8)
            ..cubicTo(20.4, 7.2, 19.4, 8.4, 18, 9.8),
        ];
      case RbGlyph.home:
        return [
          Path()
            ..moveTo(3.8, 11.2)
            ..lineTo(10.7, 5.1)
            ..cubicTo(11.5, 4.4, 12.5, 4.4, 13.3, 5.1)
            ..lineTo(20.2, 11.2),
          Path()
            ..moveTo(6.2, 9.4)
            ..lineTo(6.2, 18.4)
            ..cubicTo(6.2, 19.5, 7.1, 20.4, 8.2, 20.4)
            ..lineTo(15.8, 20.4)
            ..cubicTo(16.9, 20.4, 17.8, 19.5, 17.8, 18.4)
            ..lineTo(17.8, 9.4),
          Path()
            ..moveTo(10, 20.4)
            ..lineTo(10, 16.2)
            ..cubicTo(10, 15.1, 10.9, 14.3, 12, 14.3)
            ..cubicTo(13.1, 14.3, 14, 15.1, 14, 16.2)
            ..lineTo(14, 20.4),
        ];
      case RbGlyph.close:
        return [
          Path()
            ..moveTo(6.6, 6.6)
            ..lineTo(17.4, 17.4),
          Path()
            ..moveTo(17.4, 6.6)
            ..lineTo(6.6, 17.4),
        ];
      case RbGlyph.chevron:
        return [
          Path()
            ..moveTo(9.6, 6.4)
            ..quadraticBezierTo(13.4, 9.6, 15, 12)
            ..quadraticBezierTo(13.4, 14.4, 9.6, 17.6),
        ];
      case RbGlyph.back:
        return [
          Path()
            ..moveTo(10.6, 5.6)
            ..quadraticBezierTo(7.3, 8.7, 5, 12)
            ..quadraticBezierTo(7.3, 15.3, 10.6, 18.4),
          Path()
            ..moveTo(5.6, 12)
            ..lineTo(19, 12),
        ];
      case RbGlyph.check:
        return [
          Path()
            ..moveTo(5, 12.6)
            ..quadraticBezierTo(7.6, 14.6, 9.8, 17.4)
            ..quadraticBezierTo(13.6, 11, 19, 6.6),
        ];
      case RbGlyph.checkCircle:
        return [
          _circle(12, 12, 8.2),
          Path()
            ..moveTo(8.2, 12.4)
            ..quadraticBezierTo(9.6, 13.5, 10.9, 15.2)
            ..quadraticBezierTo(13.2, 11.4, 16.2, 8.9),
        ];
      case RbGlyph.clock:
        return [
          _circle(12, 12, 8.2),
          Path()
            ..moveTo(12, 7.6)
            ..lineTo(12, 12.2)
            ..lineTo(15.1, 14.2),
        ];
      case RbGlyph.search:
        return [
          _circle(10.6, 10.6, 5.9),
          Path()
            ..moveTo(15.1, 15.1)
            ..quadraticBezierTo(17.3, 17.5, 19.4, 19.4),
        ];
      case RbGlyph.info:
        return [
          _circle(12, 12, 8.2),
          Path()
            ..moveTo(12, 11.2)
            ..lineTo(12, 16.2),
        ];
      case RbGlyph.send:
        return [
          Path()
            ..moveTo(4.6, 11.4)
            ..lineTo(19.4, 4.6)
            ..lineTo(14.2, 19.4)
            ..lineTo(11.3, 12.9)
            ..close(),
          Path()
            ..moveTo(11.3, 12.9)
            ..lineTo(19.2, 4.8),
        ];
      case RbGlyph.eye:
        return [
          Path()
            ..moveTo(3, 12)
            ..quadraticBezierTo(7.4, 5.8, 12, 5.8)
            ..quadraticBezierTo(16.6, 5.8, 21, 12)
            ..quadraticBezierTo(16.6, 18.2, 12, 18.2)
            ..quadraticBezierTo(7.4, 18.2, 3, 12)
            ..close(),
          _circle(12, 12, 2.8),
        ];
      case RbGlyph.logout:
        return [
          Path()
            ..moveTo(13.4, 4.6)
            ..lineTo(7.6, 4.6)
            ..quadraticBezierTo(5.4, 4.6, 5.4, 6.8)
            ..lineTo(5.4, 17.2)
            ..quadraticBezierTo(5.4, 19.4, 7.6, 19.4)
            ..lineTo(13.4, 19.4),
          Path()
            ..moveTo(10.4, 12)
            ..lineTo(19.4, 12),
          Path()
            ..moveTo(16.2, 8.6)
            ..quadraticBezierTo(18.3, 10.5, 19.6, 12)
            ..quadraticBezierTo(18.3, 13.5, 16.2, 15.4),
        ];
      case RbGlyph.offline:
        return [
          Path()..moveTo(4.2, 9.4)..quadraticBezierTo(12, 2.8, 19.8, 9.4),
          Path()..moveTo(7, 12.6)..quadraticBezierTo(12, 8.6, 17, 12.6),
          Path()..moveTo(9.8, 15.8)..quadraticBezierTo(12, 14.2, 14.2, 15.8),
          Path()..moveTo(4.4, 4.4)..lineTo(19.6, 19.6),
        ];
      case RbGlyph.pen:
        return [
          Path()
            ..moveTo(5, 19)
            ..lineTo(5.6, 15.4)
            ..lineTo(15.6, 5.4)
            ..quadraticBezierTo(17, 4, 18.4, 5.4)
            ..lineTo(18.6, 5.6)
            ..quadraticBezierTo(20, 7, 18.6, 8.4)
            ..lineTo(8.6, 18.4)
            ..close(),
          Path()..moveTo(13.6, 7.4)..lineTo(16.6, 10.4),
        ];
      case RbGlyph.locate:
        return [
          _circle(12, 12, 6.4),
          _circle(12, 12, 2),
          Path()..moveTo(12, 2.8)..lineTo(12, 5.4),
          Path()..moveTo(12, 18.6)..lineTo(12, 21.2),
          Path()..moveTo(2.8, 12)..lineTo(5.4, 12),
          Path()..moveTo(18.6, 12)..lineTo(21.2, 12),
        ];
      case RbGlyph.closeCircle:
        return [
          _circle(12, 12, 8.2),
          Path()..moveTo(9.3, 9.3)..lineTo(14.7, 14.7),
          Path()..moveTo(14.7, 9.3)..lineTo(9.3, 14.7),
        ];
      case RbGlyph.alertCircle:
        return [
          _circle(12, 12, 8.2),
          Path()..moveTo(12, 7.8)..lineTo(12, 12.6),
        ];
      case RbGlyph.mobile:
        return [
          Path()..addRRect(RRect.fromRectAndRadius(const Rect.fromLTRB(6.8, 3, 17.2, 21), const Radius.circular(2.8))),
          Path()..moveTo(10.8, 17.8)..lineTo(13.2, 17.8),
        ];
      case RbGlyph.minus:
        return [Path()..moveTo(5.4, 12)..lineTo(18.6, 12)];
      case RbGlyph.hourglass:
        return [
          Path()..moveTo(6.4, 3.8)..lineTo(17.6, 3.8),
          Path()..moveTo(6.4, 20.2)..lineTo(17.6, 20.2),
          Path()
            ..moveTo(7.8, 3.8)
            ..quadraticBezierTo(7.8, 9.2, 12, 12)
            ..quadraticBezierTo(16.2, 9.2, 16.2, 3.8),
          Path()
            ..moveTo(7.8, 20.2)
            ..quadraticBezierTo(7.8, 14.8, 12, 12)
            ..quadraticBezierTo(16.2, 14.8, 16.2, 20.2),
          Path()
            ..moveTo(9.4, 19.4)
            ..quadraticBezierTo(10.2, 16.6, 12, 15.6)
            ..quadraticBezierTo(13.8, 16.6, 14.6, 19.4)
            ..close(),
        ];
      case RbGlyph.flag:
        return [
          Path()
            ..moveTo(5.8, 4.8)
            ..quadraticBezierTo(9, 3, 12.2, 4.8)
            ..quadraticBezierTo(15.4, 6.6, 18.6, 4.8)
            ..lineTo(18.6, 13.4)
            ..quadraticBezierTo(15.4, 15.2, 12.2, 13.4)
            ..quadraticBezierTo(9, 11.6, 5.8, 13.4)
            ..close(),
          Path()..moveTo(5.8, 4)..lineTo(5.8, 21),
        ];
      case RbGlyph.building:
        return [
          Path()
            ..moveTo(5, 20.4)
            ..lineTo(5, 6.2)
            ..quadraticBezierTo(5, 4.4, 6.8, 4.4)
            ..lineTo(13, 4.4)
            ..quadraticBezierTo(14.8, 4.4, 14.8, 6.2)
            ..lineTo(14.8, 20.4)
            ..close(),
          Path()
            ..moveTo(14.8, 9.6)
            ..lineTo(17.4, 9.6)
            ..quadraticBezierTo(19.2, 9.6, 19.2, 11.4)
            ..lineTo(19.2, 20.4),
          Path()..moveTo(3.6, 20.4)..lineTo(20.4, 20.4),
          Path()..moveTo(8.2, 8.4)..lineTo(11.6, 8.4),
          Path()..moveTo(8.2, 11.8)..lineTo(11.6, 11.8),
          Path()..moveTo(8.8, 20.4)..lineTo(8.8, 16.4)..lineTo(11, 16.4)..lineTo(11, 20.4),
        ];
      case RbGlyph.alert:
        return [
          Path()
            ..moveTo(10.4, 4.8)
            ..quadraticBezierTo(12, 2.4, 13.6, 4.8)
            ..lineTo(20.4, 17.2)
            ..quadraticBezierTo(21.4, 19.6, 18.8, 19.6)
            ..lineTo(5.2, 19.6)
            ..quadraticBezierTo(2.6, 19.6, 3.6, 17.2)
            ..close(),
          Path()..moveTo(12, 9.4)..lineTo(12, 13.4),
        ];
      case RbGlyph.quote:
        // Two quote marks: solid heads (drawn as dots) with curved tails.
        return [
          Path()
            ..moveTo(10.2, 6.4)
            ..quadraticBezierTo(5.8, 8, 5.6, 13.6),
          Path()
            ..moveTo(18.4, 6.4)
            ..quadraticBezierTo(14, 8, 13.8, 13.6),
        ];
      case RbGlyph.hangUp:
        return [
          Path()
            ..moveTo(3.6, 13.6)
            ..quadraticBezierTo(3.4, 11, 6, 9.6)
            ..quadraticBezierTo(12, 7, 18, 9.6)
            ..quadraticBezierTo(20.6, 11, 20.4, 13.6)
            ..lineTo(20.2, 15)
            ..quadraticBezierTo(20, 16, 19, 15.9)
            ..lineTo(16.4, 15.5)
            ..quadraticBezierTo(15.4, 15.3, 15.4, 14.3)
            ..lineTo(15.4, 12.9)
            ..quadraticBezierTo(12, 11.8, 8.6, 12.9)
            ..lineTo(8.6, 14.3)
            ..quadraticBezierTo(8.6, 15.3, 7.6, 15.5)
            ..lineTo(5, 15.9)
            ..quadraticBezierTo(4, 16, 3.8, 15)
            ..close(),
        ];
      case RbGlyph.megaphone:
        return [
          Path()
            ..moveTo(4.4, 10)
            ..quadraticBezierTo(4.4, 8.6, 5.8, 8.6)
            ..lineTo(8.6, 8.6)
            ..lineTo(16.4, 4.8)
            ..quadraticBezierTo(18.2, 4, 18.2, 5.8)
            ..lineTo(18.2, 17.2)
            ..quadraticBezierTo(18.2, 19, 16.4, 18.2)
            ..lineTo(8.6, 14.4)
            ..lineTo(5.8, 14.4)
            ..quadraticBezierTo(4.4, 14.4, 4.4, 13)
            ..close(),
          Path()
            ..moveTo(7.8, 14.4)
            ..lineTo(9, 19)
            ..quadraticBezierTo(9.3, 20.1, 10.4, 19.8)
            ..quadraticBezierTo(11.5, 19.5, 11.2, 18.4)
            ..lineTo(10.4, 15.4),
          Path()..moveTo(20.6, 9.6)..quadraticBezierTo(21.6, 11.5, 20.6, 13.4),
        ];
      case RbGlyph.photo:
        return [
          Path()..addRRect(RRect.fromRectAndRadius(const Rect.fromLTRB(3.8, 5, 20.2, 19), const Radius.circular(3))),
          _circle(9, 9.8, 1.6),
          Path()
            ..moveTo(3.8, 16.6)
            ..lineTo(8.6, 12.8)
            ..quadraticBezierTo(9.4, 12.2, 10.2, 12.8)
            ..lineTo(13, 15)
            ..lineTo(15.4, 13)
            ..quadraticBezierTo(16.2, 12.4, 17, 13)
            ..lineTo(20.2, 15.8),
        ];
      case RbGlyph.photoAdd:
        return [
          Path()..addRRect(RRect.fromRectAndRadius(const Rect.fromLTRB(3.8, 6.4, 17.2, 19.6), const Radius.circular(3))),
          Path()
            ..moveTo(3.8, 17)
            ..lineTo(8, 13.4)
            ..quadraticBezierTo(8.8, 12.8, 9.6, 13.4)
            ..lineTo(13.4, 16.6),
          Path()..moveTo(19, 2.8)..lineTo(19, 8.2),
          Path()..moveTo(16.3, 5.5)..lineTo(21.7, 5.5),
        ];
      case RbGlyph.photoOff:
        return [
          Path()..addRRect(RRect.fromRectAndRadius(const Rect.fromLTRB(3.8, 5, 20.2, 19), const Radius.circular(3))),
          Path()..moveTo(3.4, 3.4)..lineTo(20.6, 20.6),
        ];
      case RbGlyph.camera:
        return [
          Path()
            ..moveTo(4, 8.8)
            ..quadraticBezierTo(4, 7, 5.8, 7)
            ..lineTo(8, 7)
            ..lineTo(9.4, 5)
            ..lineTo(14.6, 5)
            ..lineTo(16, 7)
            ..lineTo(18.2, 7)
            ..quadraticBezierTo(20, 7, 20, 8.8)
            ..lineTo(20, 17.2)
            ..quadraticBezierTo(20, 19, 18.2, 19)
            ..lineTo(5.8, 19)
            ..quadraticBezierTo(4, 19, 4, 17.2)
            ..close(),
          _circle(12, 12.8, 3.4),
        ];
      case RbGlyph.connect:
        return [
          _circle(9, 12, 4.8),
          _circle(15, 12, 4.8),
        ];
      case RbGlyph.flame:
        return [
          Path()
            ..moveTo(12, 21)
            ..quadraticBezierTo(6.4, 21, 6.4, 15.4)
            ..quadraticBezierTo(6.4, 11.6, 9.6, 8.8)
            ..quadraticBezierTo(9.8, 11.4, 11.6, 12.2)
            ..quadraticBezierTo(11, 7.4, 13.8, 3.4)
            ..quadraticBezierTo(14.6, 7.4, 16.8, 9.8)
            ..quadraticBezierTo(17.6, 11.4, 17.6, 15.4)
            ..quadraticBezierTo(17.6, 21, 12, 21)
            ..close(),
          Path()
            ..moveTo(12, 18.4)
            ..quadraticBezierTo(10.2, 18.4, 10.2, 16.6)
            ..quadraticBezierTo(10.2, 15.2, 12, 13.8)
            ..quadraticBezierTo(13.8, 15.2, 13.8, 16.6)
            ..quadraticBezierTo(13.8, 18.4, 12, 18.4),
        ];
      case RbGlyph.clipboard:
        return [
          Path()..addRRect(RRect.fromRectAndRadius(const Rect.fromLTRB(5.4, 5, 18.6, 21), const Radius.circular(2.6))),
          Path()..addRRect(RRect.fromRectAndRadius(const Rect.fromLTRB(9, 3, 15, 6.8), const Radius.circular(1.4))),
          Path()..moveTo(8.6, 11.2)..lineTo(15.4, 11.2),
          Path()..moveTo(8.6, 14.6)..lineTo(15.4, 14.6),
          Path()..moveTo(8.6, 18)..lineTo(12.4, 18),
        ];
      case RbGlyph.chevronDown:
        return [Path()..moveTo(6.4, 9.6)..quadraticBezierTo(9.6, 13.4, 12, 15)..quadraticBezierTo(14.4, 13.4, 17.6, 9.6)];
      case RbGlyph.verified:
        return [
          _drop(12, 2.6, 13.2, 18.8),
          Path()
            ..moveTo(9.2, 14.2)
            ..quadraticBezierTo(10.4, 15, 11.3, 16.3)
            ..quadraticBezierTo(12.9, 13.6, 14.9, 12),
        ];
      case RbGlyph.forward:
        return [
          Path()..moveTo(13.4, 5.6)..quadraticBezierTo(16.7, 8.7, 19, 12)..quadraticBezierTo(16.7, 15.3, 13.4, 18.4),
          Path()..moveTo(18.4, 12)..lineTo(5, 12),
        ];
      case RbGlyph.speaker:
        return [
          Path()
            ..moveTo(4.4, 9.6)
            ..quadraticBezierTo(4.4, 8.8, 5.2, 8.8)
            ..lineTo(8, 8.8)
            ..lineTo(12.4, 5)
            ..quadraticBezierTo(13.6, 4.2, 13.6, 5.6)
            ..lineTo(13.6, 18.4)
            ..quadraticBezierTo(13.6, 19.8, 12.4, 19)
            ..lineTo(8, 15.2)
            ..lineTo(5.2, 15.2)
            ..quadraticBezierTo(4.4, 15.2, 4.4, 14.4)
            ..close(),
          Path()..moveTo(16.4, 9.2)..quadraticBezierTo(18, 12, 16.4, 14.8),
          Path()..moveTo(18.8, 6.8)..quadraticBezierTo(22, 12, 18.8, 17.2),
        ];
      case RbGlyph.retry:
        return [
          Path()
            ..moveTo(19.4, 12.6)
            ..quadraticBezierTo(19, 19.8, 12, 19.8)
            ..quadraticBezierTo(4.4, 19.8, 4.4, 12)
            ..quadraticBezierTo(4.4, 4.4, 12, 4.4)
            ..quadraticBezierTo(16, 4.4, 18.4, 7.4),
          Path()..moveTo(19, 3.8)..lineTo(19, 7.8)..lineTo(15, 7.8),
        ];
      case RbGlyph.phoneMissed:
        return [
          _handset(),
          Path()..moveTo(14.8, 3.8)..lineTo(17.6, 6.6)..lineTo(20.6, 3.6),
        ];
      case RbGlyph.mic:
        return [
          Path()..addRRect(RRect.fromRectAndRadius(const Rect.fromLTRB(9, 3.4, 15, 14), const Radius.circular(3))),
          Path()..moveTo(5.8, 11)..quadraticBezierTo(5.8, 17.2, 12, 17.2)..quadraticBezierTo(18.2, 17.2, 18.2, 11),
          Path()..moveTo(12, 17.2)..lineTo(12, 20.6),
          Path()..moveTo(9, 20.6)..lineTo(15, 20.6),
        ];
      case RbGlyph.micOff:
        return [
          Path()..addRRect(RRect.fromRectAndRadius(const Rect.fromLTRB(9, 3.4, 15, 14), const Radius.circular(3))),
          Path()..moveTo(5.8, 11)..quadraticBezierTo(5.8, 17.2, 12, 17.2)..quadraticBezierTo(18.2, 17.2, 18.2, 11),
          Path()..moveTo(12, 17.2)..lineTo(12, 20.6),
          Path()..moveTo(4.4, 3.8)..lineTo(19.6, 19.8),
        ];
      case RbGlyph.inbox:
        return [
          Path()
            ..moveTo(4, 13.4)
            ..lineTo(6.4, 5.8)
            ..quadraticBezierTo(6.8, 4.6, 8, 4.6)
            ..lineTo(16, 4.6)
            ..quadraticBezierTo(17.2, 4.6, 17.6, 5.8)
            ..lineTo(20, 13.4)
            ..lineTo(20, 17.6)
            ..quadraticBezierTo(20, 19.4, 18.2, 19.4)
            ..lineTo(5.8, 19.4)
            ..quadraticBezierTo(4, 19.4, 4, 17.6)
            ..close(),
          Path()..moveTo(4, 13.4)..lineTo(8.4, 13.4)..quadraticBezierTo(9, 16, 12, 16)..quadraticBezierTo(15, 16, 15.6, 13.4)..lineTo(20, 13.4),
        ];
      case RbGlyph.heart:
        return [
          Path()
            ..moveTo(12, 20)
            ..quadraticBezierTo(4, 14.6, 4, 9.4)
            ..quadraticBezierTo(4, 5.6, 7.6, 5.6)
            ..quadraticBezierTo(10.4, 5.6, 12, 8.2)
            ..quadraticBezierTo(13.6, 5.6, 16.4, 5.6)
            ..quadraticBezierTo(20, 5.6, 20, 9.4)
            ..quadraticBezierTo(20, 14.6, 12, 20)
            ..close(),
        ];
      case RbGlyph.globe:
        return [
          _circle(12, 12, 8.4),
          Path()..moveTo(3.8, 12)..lineTo(20.2, 12),
          Path()..moveTo(12, 3.6)..quadraticBezierTo(16.2, 8, 16.2, 12)..quadraticBezierTo(16.2, 16, 12, 20.4),
          Path()..moveTo(12, 3.6)..quadraticBezierTo(7.8, 8, 7.8, 12)..quadraticBezierTo(7.8, 16, 12, 20.4),
        ];
      case RbGlyph.pageClock:
        return [
          Path()
            ..moveTo(14.2, 3.4)
            ..lineTo(7.4, 3.4)
            ..cubicTo(6.3, 3.4, 5.4, 4.3, 5.4, 5.4)
            ..lineTo(5.4, 18.6)
            ..cubicTo(5.4, 19.7, 6.3, 20.6, 7.4, 20.6)
            ..lineTo(11, 20.6),
          Path()..moveTo(14, 3.6)..lineTo(14, 6.6)..cubicTo(14, 7.3, 14.5, 7.8, 15.2, 7.8)..lineTo(18.4, 7.8)..lineTo(18.6, 10.4),
          _circle(16.2, 16.2, 4.2),
          Path()..moveTo(16.2, 14.2)..lineTo(16.2, 16.4)..lineTo(17.6, 17.4),
        ];
      case RbGlyph.eyeOff:
        return [
          Path()
            ..moveTo(3, 12)
            ..quadraticBezierTo(7.4, 5.8, 12, 5.8)
            ..quadraticBezierTo(16.6, 5.8, 21, 12)
            ..quadraticBezierTo(16.6, 18.2, 12, 18.2)
            ..quadraticBezierTo(7.4, 18.2, 3, 12)
            ..close(),
          Path()..moveTo(4.2, 4.2)..lineTo(19.8, 19.8),
        ];
      case RbGlyph.copy:
        return [
          Path()..addRRect(RRect.fromRectAndRadius(const Rect.fromLTRB(8.6, 8.6, 19.6, 19.6), const Radius.circular(2.6))),
          Path()
            ..moveTo(15.4, 8.6)
            ..lineTo(15.4, 6.4)
            ..quadraticBezierTo(15.4, 4.4, 13.4, 4.4)
            ..lineTo(6.4, 4.4)
            ..quadraticBezierTo(4.4, 4.4, 4.4, 6.4)
            ..lineTo(4.4, 13.4)
            ..quadraticBezierTo(4.4, 15.4, 6.4, 15.4)
            ..lineTo(8.6, 15.4),
        ];
      case RbGlyph.calendar:
        return [
          Path()..addRRect(RRect.fromRectAndRadius(const Rect.fromLTRB(4, 5.4, 20, 20), const Radius.circular(3))),
          Path()..moveTo(4, 10)..lineTo(20, 10),
          Path()..moveTo(8.4, 3.4)..lineTo(8.4, 7),
          Path()..moveTo(15.6, 3.4)..lineTo(15.6, 7),
        ];
      case RbGlyph.trash:
        return [
          Path()..moveTo(4.4, 6.6)..lineTo(19.6, 6.6),
          Path()
            ..moveTo(6.4, 6.6)
            ..lineTo(7.2, 18.6)
            ..quadraticBezierTo(7.4, 20.4, 9.2, 20.4)
            ..lineTo(14.8, 20.4)
            ..quadraticBezierTo(16.6, 20.4, 16.8, 18.6)
            ..lineTo(17.6, 6.6),
          Path()..moveTo(9.4, 6.6)..lineTo(9.4, 5)..quadraticBezierTo(9.4, 3.6, 10.8, 3.6)..lineTo(13.2, 3.6)..quadraticBezierTo(14.6, 3.6, 14.6, 5)..lineTo(14.6, 6.6),
          Path()..moveTo(10.4, 10.4)..lineTo(10.6, 16.6),
          Path()..moveTo(13.6, 10.4)..lineTo(13.4, 16.6),
        ];
      case RbGlyph.mail:
        return [
          Path()..addRRect(RRect.fromRectAndRadius(const Rect.fromLTRB(3.6, 5.4, 20.4, 18.6), const Radius.circular(3))),
          Path()..moveTo(4.4, 7.2)..quadraticBezierTo(8.6, 11, 12, 12.6)..quadraticBezierTo(15.4, 11, 19.6, 7.2),
        ];
      case RbGlyph.bellOff:
        return [
          Path()
            ..moveTo(5, 17.2)
            ..cubicTo(6.2, 16, 6.6, 14.6, 6.6, 12.8)
            ..lineTo(6.6, 10.6)
            ..cubicTo(6.6, 7.5, 9, 5, 12, 5)
            ..cubicTo(15, 5, 17.4, 7.5, 17.4, 10.6)
            ..lineTo(17.4, 12.8)
            ..cubicTo(17.4, 14.6, 17.8, 16, 19, 17.2)
            ..close(),
          Path()..moveTo(10.2, 20)..quadraticBezierTo(12, 21.4, 13.8, 20),
          Path()..moveTo(4, 3.6)..lineTo(20, 20.4),
        ];
      case RbGlyph.share:
        // An open tray with the arrow leaving it.
        return [
          Path()
            ..moveTo(8, 9.4)
            ..lineTo(6.6, 9.4)
            ..quadraticBezierTo(4.8, 9.4, 4.8, 11.2)
            ..lineTo(4.8, 18.4)
            ..quadraticBezierTo(4.8, 20.2, 6.6, 20.2)
            ..lineTo(17.4, 20.2)
            ..quadraticBezierTo(19.2, 20.2, 19.2, 18.4)
            ..lineTo(19.2, 11.2)
            ..quadraticBezierTo(19.2, 9.4, 17.4, 9.4)
            ..lineTo(16, 9.4),
          Path()..moveTo(12, 14)..lineTo(12, 3.6),
          Path()..moveTo(8.6, 6.8)..lineTo(12, 3.6)..lineTo(15.4, 6.8),
        ];
      case RbGlyph.download:
        return [
          Path()..moveTo(12, 3.8)..lineTo(12, 14.4),
          Path()..moveTo(8, 10.6)..lineTo(12, 14.6)..lineTo(16, 10.6),
          Path()
            ..moveTo(4.8, 15.4)
            ..lineTo(4.8, 17.6)
            ..quadraticBezierTo(4.8, 20, 7.2, 20)
            ..lineTo(16.8, 20)
            ..quadraticBezierTo(19.2, 20, 19.2, 17.6)
            ..lineTo(19.2, 15.4),
        ];
      case RbGlyph.settings:
        // Two slider rails with soft knobs — calmer than a cog.
        return [
          _circle(9, 8, 2.4),
          _circle(15, 16, 2.4),
          Path()..moveTo(4.2, 8)..lineTo(6.6, 8),
          Path()..moveTo(11.4, 8)..lineTo(19.8, 8),
          Path()..moveTo(4.2, 16)..lineTo(12.6, 16),
          Path()..moveTo(17.4, 16)..lineTo(19.8, 16),
        ];
      case RbGlyph.idCard:
        return [
          Path()..addRRect(RRect.fromRectAndRadius(const Rect.fromLTRB(3.4, 5.6, 20.6, 18.4), const Radius.circular(3))),
          _circle(8.8, 10.8, 1.9),
          Path()..moveTo(6, 15.4)..quadraticBezierTo(8.8, 13.2, 11.6, 15.4),
          Path()..moveTo(14, 10)..lineTo(17.6, 10),
          Path()..moveTo(14, 13.4)..lineTo(16.6, 13.4),
        ];
      case RbGlyph.radar:
        // Search rings around a droplet — used for "finding donors".
        return [
          _circle(12, 12, 8.4),
          Path()..addArc(Rect.fromCircle(center: const Offset(12, 12), radius: 4.6), -2.4, 3.6),
          _drop(12, 8.8, 3.6, 5.4),
          Path()..moveTo(12, 12)..lineTo(18, 6.2),
        ];
      case RbGlyph.plus:
        return [
          Path()
            ..moveTo(12, 5.4)
            ..lineTo(12, 18.6),
          Path()
            ..moveTo(5.4, 12)
            ..lineTo(18.6, 12),
        ];
    }
  }

  /// Which closed forms get the duotone fill. Small action marks (close,
  /// plus, chevron, back, check) stay pure line so they read as controls.
  static List<Path> _accents(RbGlyph g) {
    final paths = _paths(g);
    return switch (g) {
      RbGlyph.droplet || RbGlyph.find || RbGlyph.pin || RbGlyph.phone || RbGlyph.message || RbGlyph.shield || RbGlyph.page || RbGlyph.bell || RbGlyph.checkCircle || RbGlyph.clock || RbGlyph.info || RbGlyph.send || RbGlyph.eye || RbGlyph.lock => [paths.first],
      RbGlyph.community => [paths[0]],
      RbGlyph.person => [paths[0]],
      RbGlyph.history => [paths[2]],
      RbGlyph.certificate => [paths[0]],
      RbGlyph.phoneHeart => [paths[1]],
      RbGlyph.route => [paths[2]],
      RbGlyph.home => [
          Path()
            ..moveTo(6.2, 9.4)
            ..lineTo(12, 4.6)
            ..lineTo(17.8, 9.4)
            ..lineTo(17.8, 20.4)
            ..lineTo(6.2, 20.4)
            ..close(),
        ],
      RbGlyph.pen => [paths[0]],
      RbGlyph.locate => [paths[0]],
      RbGlyph.closeCircle => [paths[0]],
      RbGlyph.alertCircle => [paths[0]],
      RbGlyph.mobile => [paths[0]],
      RbGlyph.hourglass => [paths[4]],
      RbGlyph.flag => [paths[0]],
      RbGlyph.building => [paths[0]],
      RbGlyph.alert => [paths[0]],
      RbGlyph.hangUp => [paths[0]],
      RbGlyph.megaphone => [paths[0]],
      RbGlyph.photo => [paths[0]],
      RbGlyph.photoAdd => [paths[0]],
      RbGlyph.photoOff => [paths[0]],
      RbGlyph.camera => [paths[0]],
      RbGlyph.connect => [paths[0]],
      RbGlyph.flame => [paths[0]],
      RbGlyph.clipboard => [paths[0]],
      RbGlyph.verified => [paths[0]],
      RbGlyph.speaker => [paths[0]],
      RbGlyph.phoneMissed => [paths[0]],
      RbGlyph.mic => [paths[0]],
      RbGlyph.micOff => [paths[0]],
      RbGlyph.inbox => [paths[0]],
      RbGlyph.heart => [paths[0]],
      RbGlyph.globe => [paths[0]],
      RbGlyph.pageClock => [paths[2]],
      RbGlyph.eyeOff => [paths[0]],
      RbGlyph.copy => [paths[0]],
      RbGlyph.calendar => [paths[0]],
      RbGlyph.mail => [paths[0]],
      RbGlyph.bellOff => [paths[0]],
      RbGlyph.idCard => [paths[0]],
      RbGlyph.radar => [paths[2]],
      _ => const [],
    };
  }

  static Path _handset() => Path()
    ..moveTo(7.1, 3.8)
    ..cubicTo(5.6, 3.8, 4.3, 5.1, 4.5, 6.6)
    ..cubicTo(5.3, 13.4, 10.6, 18.7, 17.4, 19.5)
    ..cubicTo(18.9, 19.7, 20.2, 18.4, 20.2, 16.9)
    ..lineTo(20.2, 15.3)
    ..cubicTo(20.2, 14.6, 19.7, 14, 19, 13.9)
    ..lineTo(16.6, 13.4)
    ..cubicTo(16, 13.3, 15.4, 13.5, 15.1, 14)
    ..lineTo(14.4, 15)
    ..cubicTo(12, 13.8, 10.2, 12, 9, 9.6)
    ..lineTo(10, 8.9)
    ..cubicTo(10.5, 8.6, 10.7, 8, 10.6, 7.4)
    ..lineTo(10.1, 5)
    ..cubicTo(10, 4.3, 9.4, 3.8, 8.7, 3.8)
    ..close();

  static List<(Offset, double)> _dots(RbGlyph g) => switch (g) {
        RbGlyph.more => const [(Offset(5.6, 12), 1.7), (Offset(12, 12), 1.7), (Offset(18.4, 12), 1.7)],
        RbGlyph.info => const [(Offset(12, 7.9), 1.2)],
        RbGlyph.quote => const [(Offset(7.9, 14.4), 2.5), (Offset(16.1, 14.4), 2.5)],
        RbGlyph.alert => const [(Offset(12, 16.4), 1.15)],
        RbGlyph.alertCircle => const [(Offset(12, 16.2), 1.15)],
        RbGlyph.offline => const [(Offset(12, 19), 1.2)],
        RbGlyph.calendar => const [(Offset(8.6, 14.2), 1.0), (Offset(12, 14.2), 1.0), (Offset(15.4, 14.2), 1.0)],
        _ => const [],
      };
}
