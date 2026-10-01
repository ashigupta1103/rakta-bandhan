import 'package:flutter/material.dart';

import '../services/maps_link.dart';
import '../theme/app_colors.dart';
import 'rb_icon.dart';

/// A request's place as readable text that opens Google Maps when tapped.
/// Coordinates are used only inside the link, never shown. Without a
/// stored point it is plain text.
class PlaceLink extends StatelessWidget {
  final String label;
  final double? lat;
  final double? lng;
  final TextStyle style;
  final int maxLines;
  final Color iconColor;

  const PlaceLink({super.key, required this.label, required this.lat, required this.lng, required this.style, this.maxLines = 2, this.iconColor = AppColors.brandRed});

  @override
  Widget build(BuildContext context) {
    final text = Text(label, maxLines: maxLines, overflow: TextOverflow.ellipsis, style: style);
    if (lat == null || lng == null) return text;
    return Semantics(
      button: true,
      label: 'Open $label in Google Maps',
      excludeSemantics: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () async {
          final ok = await openInMaps(lat!, lng!);
          if (!ok && context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Couldn’t open Google Maps on this device.')));
          }
        },
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Flexible(child: text),
            Padding(padding: const EdgeInsets.only(left: 8, top: 3), child: RbIcon(RbGlyph.pin, size: 17, color: iconColor)),
          ],
        ),
      ),
    );
  }
}
