/// Map + geocoding providers, in one place so switching is a one-line
/// change. See docs/publishing/README.md ("Map tiles and geocoding").
library;

/// LocationIQ key for address search / reverse geocoding (free tier:
/// 5,000 requests/day; same response format as Nominatim). Leave empty in
/// development to use the public OpenStreetMap Nominatim server — its
/// usage policy allows ~1 request/second and no production autocomplete,
/// so a key is required before launch.
const kLocationIqKey = '';

/// Results restricted to India — "Apollo Hospital" should never resolve to
/// a match abroad.
const kGeocodeCountryCodes = 'in';

/// Native Google Maps (Android/iOS) instead of flutter_map raster tiles.
/// Google's Maps SDK map loads are free and unlimited on mobile — the only
/// map option that stays free at 1 lakh users (tile APIs bill per tile).
/// Turn on by building with `--dart-define=GOOGLE_MAPS=true` after adding
/// the key:
///   Android: MAPS_API_KEY=... in android/local.properties (or env var)
///   iOS:     GOOGLE_MAPS_API_KEY=... in ios/Flutter/Release.xcconfig
/// Restrict the key to the app (package + SHA-1 / bundle ID) and to "Maps
/// SDK for Android" / "Maps SDK for iOS" only.
const kUseGoogleMaps = bool.fromEnvironment('GOOGLE_MAPS');

/// Raster tiles (flutter_map fallback). Default: OpenStreetMap's standard style in full colour
/// (the old build greyscaled it, which is why streets and landmarks were
/// hard to read). Verified 26 Sep 2026: CARTO's keyless basemaps now return
/// an "API KEY REQUIRED" tile, so they're not an option without signing up.
///
/// OSM's public tile server is fine for development but its usage policy
/// discourages production-app load. For launch, create a free MapTiler key
/// (100k tile loads/month free) and switch to:
///   'https://api.maptiler.com/maps/streets-v2/256/{z}/{x}/{y}@2x.png?key=YOUR_KEY'
/// with no subdomains and attribution '© MapTiler © OpenStreetMap contributors'.
const kTileUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
const kTileSubdomains = <String>[];
const kTileAttribution = '© OpenStreetMap contributors';
