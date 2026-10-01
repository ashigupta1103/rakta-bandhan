import 'package:url_launcher/url_launcher.dart';

/// Google's universal Maps URL for a stored point. On Android and iOS it
/// opens the Google Maps app when installed (browser otherwise). The
/// coordinates only travel inside the link — the app itself shows the
/// human-readable place, never the numbers.
Uri mapsUri(double lat, double lng) =>
    Uri.https('www.google.com', '/maps/search/', {'api': '1', 'query': '$lat,$lng'});

/// Opens [lat],[lng] in Google Maps. Returns false if nothing could open it.
Future<bool> openInMaps(double lat, double lng) async {
  try {
    return await launchUrl(mapsUri(lat, lng), mode: LaunchMode.externalApplication);
  } catch (_) {
    return false;
  }
}
