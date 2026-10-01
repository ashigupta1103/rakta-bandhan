import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gm;
import 'package:latlong2/latlong.dart' hide Path;
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../services/backend.dart';
import '../services/nearby_donors.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../theme/app_theme.dart';
import '../widgets/blood_group_droplet.dart';
import '../widgets/filter_chip_row.dart';
import '../widgets/map_markers.dart';
import '../widgets/map_tiles.dart';
import '../widgets/state_card.dart';
import 'donor_details_screen.dart';
import 'location_picker_screen.dart';

enum _MapPermissionState { checking, prompt, granted, denied }

/// Find tab root — a real tiled map with every marker projected from the
/// donor's own real `lat`/`lng` in `donors_public` (Phase 3, per the final
/// artifact's "Find — tab root · real map" section: "no marker has a
/// hard-coded position, and no donor location is fabricated").
///
/// MAP: flutter_map with the provider configured in services/geo_config.dart
/// (shared with the location picker via widgets/map_tiles.dart). Donor pins
/// use the ~1 km-rounded public coordinates by design; the searching user's
/// own dot is their real GPS fix. Donors are loaded with NearbyDonors (a
/// bounded geohash query), never a whole-collection scan.
class FindDonorsScreen extends StatefulWidget {
  /// False when embedded as the Find tab root — there is no route to pop
  /// back to, so the leading back affordance is omitted rather than left
  /// wired to a `Navigator.pop` that would close the tab shell itself.
  final bool showBackButton;

  const FindDonorsScreen({super.key, this.showBackButton = true});

  @override
  State<FindDonorsScreen> createState() => _FindDonorsScreenState();
}

class _FindDonorsScreenState extends State<FindDonorsScreen> {
  final TextEditingController _searchController = TextEditingController();
  final MapController _mapController = MapController();
  gm.GoogleMapController? _gmap;
  final DraggableScrollableController _sheetController = DraggableScrollableController();
  Position? _position;
  _MapPermissionState _permissionState = _MapPermissionState.checking;
  double _sheetExtent = 0.42;
  bool _recentering = false;

  List<Map<String, dynamic>> _suggestions = [];
  String? _searchedLabel;
  bool _searching = false;
  Timer? _debounce;

  String _bloodGroupFilter = 'All';
  String? _highlightedDonorId;
  String? _sendingDonorId;
  int _retryToken = 0;

  /// Bounded donor query around the current search centre (see
  /// NearbyDonors). Rebuilt only when the centre moves to another ~5 km
  /// cell or the user retries — not on every setState, which used to
  /// re-subscribe a whole-collection listener on each rebuild.
  NearbyDonors? _nearby;
  String? _nearbyKey;

  Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>> get _donorStream {
    final p = _position;
    if (p == null) return Stream.value(const []);
    final key = '${NearbyDonors.cellOf(p.latitude, p.longitude)}#$_retryToken';
    if (key != _nearbyKey) {
      _nearby?.dispose();
      _nearby = NearbyDonors(p.latitude, p.longitude);
      _nearbyKey = key;
    }
    return _nearby!.stream;
  }

  static const _bloodGroups = ['All', 'A+', 'A-', 'B+', 'B-', 'O+', 'O-', 'AB+', 'AB-'];

  /// The geohash grid query (Backend.availableDonorsNearbyStream) only
  /// bounds which documents Firestore returns — this is the real cutoff
  /// applied to that candidate set below.
  static const _searchRadiusKm = 50.0;

  @override
  void initState() {
    super.initState();
    _checkPermission();
    _sheetController.addListener(() {
      if (_sheetController.isAttached) setState(() => _sheetExtent = _sheetController.size);
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _sheetController.dispose();
    _nearby?.dispose();
    super.dispose();
  }

  Future<void> _checkPermission() async {
    setState(() => _permissionState = _MapPermissionState.checking);
    final permission = await Geolocator.checkPermission();
    final granted = permission == LocationPermission.always || permission == LocationPermission.whileInUse;
    if (!mounted) return;
    if (granted) {
      _permissionState = _MapPermissionState.granted;
      _loadPosition();
    } else {
      setState(() => _permissionState = _MapPermissionState.prompt);
    }
  }

  Future<void> _requestPermission() async {
    final permission = await Geolocator.requestPermission();
    if (!mounted) return;
    final granted = permission == LocationPermission.always || permission == LocationPermission.whileInUse;
    setState(() => _permissionState = granted ? _MapPermissionState.granted : _MapPermissionState.denied);
    if (granted) _loadPosition();
  }

  Future<void> _loadPosition() async {
    final p = await Backend.instance.currentPosition();
    if (!mounted) return;
    setState(() => _position = p);
    if (Backend.isFallback(p)) _warnFallback();
  }

  /// The map opened on the default city because there's no GPS fix — say
  /// so, instead of letting someone read distances from a place they're not.
  void _warnFallback() {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      duration: Duration(seconds: 5),
      content: Text('Couldn’t get your location, so this shows Thiruvananthapuram. Search for your area, or tap locate once GPS is on.'),
    ));
  }

  /// Google Maps-style recenter: re-fetches a fresh GPS fix (not the last
  /// cached one, which may be a search result the donor picked) and pans
  /// the map back to it.
  Future<void> _recenter() async {
    if (_recentering) return;
    setState(() => _recentering = true);
    try {
      final p = await Backend.instance.preciseLocation();
      if (!mounted) return;
      if (p == null) {
        _warnFallback();
        return;
      }
      setState(() {
        _position = p;
        _searchController.clear();
        _searchedLabel = null;
      });
      _moveMap(p.latitude, p.longitude, 15);
    } finally {
      if (mounted) setState(() => _recentering = false);
    }
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    if (value.trim().length < 3) {
      setState(() => _suggestions = []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 400), () async {
      setState(() => _searching = true);
      final results = await Backend.instance.searchAddress(value);
      if (!mounted) return;
      setState(() {
        _suggestions = results;
        _searching = false;
      });
    });
  }

  void _pickLocation(Map<String, dynamic> suggestion) {
    final lat = suggestion['lat'] as double;
    final lng = suggestion['lng'] as double;
    setState(() {
      _searchController.text = suggestion['label'] as String;
      _searchedLabel = suggestion['label'] as String;
      _position = Position(
        latitude: lat,
        longitude: lng,
        timestamp: DateTime.now(),
        accuracy: 0,
        altitude: 0,
        altitudeAccuracy: 0,
        heading: 0,
        headingAccuracy: 0,
        speed: 0,
        speedAccuracy: 0,
      );
      _suggestions = [];
    });
    _moveMap(lat, lng, null);
  }

  /// Moves whichever map engine is on screen; a null [zoom] keeps the
  /// current zoom level.
  void _moveMap(double lat, double lng, double? zoom) {
    if (useGoogleMaps) {
      final target = gm.LatLng(lat, lng);
      _gmap?.animateCamera(zoom == null ? gm.CameraUpdate.newLatLng(target) : gm.CameraUpdate.newLatLngZoom(target, zoom));
    } else {
      _mapController.move(LatLng(lat, lng), zoom ?? _mapController.camera.zoom);
    }
  }

  /// Native Google map with painted donor pins (DonorMarkerIcons); a pin
  /// with no icon ready yet shows Google's default red marker for a frame.
  Widget _googleMap(List<Map<String, dynamic>> mappable) {
    final ratio = MediaQuery.devicePixelRatioOf(context);
    final markers = <gm.Marker>{};
    for (var i = 0; i < mappable.length; i++) {
      final d = mappable[i];
      final group = d['bloodGroup'] as String;
      final primary = i == 0;
      final highlighted = _highlightedDonorId == d['id'];
      final icon = DonorMarkerIcons.peek(group, primary: primary, highlighted: highlighted);
      if (icon == null) {
        DonorMarkerIcons.warm(group, primary: primary, highlighted: highlighted, pixelRatio: ratio).then((_) {
          if (mounted) setState(() {});
        });
      }
      markers.add(gm.Marker(
        markerId: gm.MarkerId(d['id'] as String),
        position: gm.LatLng(d['lat'] as double, d['lng'] as double),
        icon: icon ?? gm.BitmapDescriptor.defaultMarkerWithHue(gm.BitmapDescriptor.hueRed),
        anchor: const Offset(0.5, 1),
        zIndexInt: highlighted ? 2 : (primary ? 1 : 0),
        onTap: () => setState(() => _highlightedDonorId = d['id'] as String),
      ));
    }
    return gm.GoogleMap(
      initialCameraPosition: gm.CameraPosition(target: gm.LatLng(_position!.latitude, _position!.longitude), zoom: 13),
      onMapCreated: (c) => _gmap = c,
      myLocationEnabled: !Backend.isFallback(_position!),
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      mapToolbarEnabled: false,
      compassEnabled: false,
      rotateGesturesEnabled: false,
      tiltGesturesEnabled: false,
      // Keep Google's logo clear of the donor sheet.
      padding: EdgeInsets.only(bottom: MediaQuery.sizeOf(context).height * _sheetExtent),
      markers: markers,
    );
  }

  void _clearSearch() {
    setState(() {
      _searchController.clear();
      _searchedLabel = null;
      _suggestions = [];
    });
    _loadPosition();
  }

  Future<void> _sendRequestTo(Map<String, dynamic> donor) async {
    final donorId = donor['id'] as String;
    if (_sendingDonorId != null) return; // guards against a double-tap firing two requests
    setState(() => _sendingDonorId = donorId);
    final bloodGroup = donor['bloodGroup'] as String;
    try {
      // The search centre is only a valid request location if it's a real
      // fix or a searched place — never the default-city fallback.
      var pos = _position;
      if (pos == null || Backend.isFallback(pos)) {
        pos = await Backend.instance.preciseLocation();
      }
      if (pos == null) {
        if (!mounted) return;
        final picked = await LocationPickerScreen.open(context, title: 'Where is the blood needed?', confirmLabel: 'Send request here');
        if (picked == null) {
          if (mounted) setState(() => _sendingDonorId = null);
          return;
        }
        pos = Position(
          latitude: picked.lat,
          longitude: picked.lng,
          timestamp: DateTime.now(),
          accuracy: 1,
          altitude: 0,
          altitudeAccuracy: 0,
          heading: 0,
          headingAccuracy: 0,
          speed: 0,
          speedAccuracy: 0,
        );
      }
      await Backend.instance.createRequest(
        bloodGroup: bloodGroup,
        unitsNeeded: 1,
        urgency: 'urgent',
        lat: pos.latitude,
        lng: pos.longitude,
        locationLabel: _searchedLabel ?? 'Requested via Find Donors',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$bloodGroup blood request sent — visible to nearby donors.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not send request. Please try again.')),
      );
    } finally {
      if (mounted) setState(() => _sendingDonorId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.mapBase,
      body: Stack(
        children: [
          if (_permissionState == _MapPermissionState.granted && _position != null)
            StreamBuilder<List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
              key: ValueKey(_nearbyKey),
              stream: _donorStream,
              builder: (context, snapshot) {
                final myUid = Backend.instance.currentUser?.uid;
                final donors = (snapshot.data ?? const [])
                    .where((d) => d.id != myUid)
                    .map(_donorCardData)
                    .where((d) => _bloodGroupFilter == 'All' || d['bloodGroup'] == _bloodGroupFilter)
                    .where((d) => (d['distanceKm'] as double?) == null || (d['distanceKm'] as double) <= _searchRadiusKm)
                    .toList()
                  ..sort((a, b) {
                    final da = a['distanceKm'] as double?;
                    final db = b['distanceKm'] as double?;
                    if (da == null && db == null) return 0;
                    if (da == null) return 1;
                    if (db == null) return -1;
                    return da.compareTo(db);
                  });
                final mappable = donors.where((d) => d['lat'] != null && d['lng'] != null).toList();

                if (useGoogleMaps) return _googleMap(mappable);
                return FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: LatLng(_position!.latitude, _position!.longitude),
                    initialZoom: 13,
                    interactionOptions: const InteractionOptions(flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
                  ),
                  children: [
                    ...appMapBase(),
                    appMapAttribution(),
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: LatLng(_position!.latitude, _position!.longitude),
                          width: 26,
                          height: 26,
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.primary,
                              border: Border.all(color: Colors.white, width: 3),
                              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 6, offset: const Offset(0, 2))],
                            ),
                          ),
                        ),
                        for (var i = 0; i < mappable.length; i++)
                          Marker(
                            point: LatLng(mappable[i]['lat'] as double, mappable[i]['lng'] as double),
                            width: i == 0 ? 56 : 44,
                            height: i == 0 ? 70 : 58,
                            // The marker's pointer tail — not its disc — is
                            // the true location; anchor the bottom of the
                            // widget (the tail's tip) to the coordinate, not
                            // the top, or every pin reads as offset south of
                            // the donor's real position.
                            alignment: Alignment.bottomCenter,
                            child: _buildMapPin(mappable[i], primary: i == 0),
                          ),
                      ],
                    ),
                    const RichAttributionWidget(
                      alignment: AttributionAlignment.bottomLeft,
                      attributions: [TextSourceAttribution('© OpenStreetMap contributors')],
                    ),
                  ],
                );
              },
            ),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (widget.showBackButton) ...[
                        _floatingCircleButton(icon: LucideIcons.arrowLeft, onTap: () => Navigator.pop(context)),
                        const SizedBox(width: 8),
                      ],
                      Expanded(child: _searchBar()),
                    ],
                  ),
                  const SizedBox(height: 10),
                  FilterChipRow(
                    activeBg: AppColors.textPrimaryWarm,
                    chips: [
                      for (final group in _bloodGroups)
                        FilterChipItem(label: group, active: _bloodGroupFilter == group, onTap: () => setState(() => _bloodGroupFilter = group)),
                    ],
                  ),
                ],
              ),
            ),
          ),

          if (_permissionState == _MapPermissionState.checking) const _MapLoadingOverlay(message: 'Checking location access…'),
          if (_permissionState == _MapPermissionState.prompt)
            _MapOverlay(
              secondaryLabel: 'Not now',
              onSecondary: () => setState(() {
                _permissionState = _MapPermissionState.granted;
                _loadPosition();
              }),
              child: StateCard.permission(
                title: 'Allow location access',
                message: 'We use your location to find compatible donors and requests nearby.',
                actionLabel: 'Allow',
                onAction: _requestPermission,
              ),
            ),
          if (_permissionState == _MapPermissionState.denied)
            _MapOverlay(
              child: StateCard(
                icon: LucideIcons.alertTriangle,
                iconBackground: AppColors.warmAmberBg,
                iconColor: AppColors.warmAmberText,
                title: 'Location access denied',
                message: "Enable location for Rakta Bandhan in your phone's settings to find nearby donors.",
                actionLabel: 'Open settings',
                onAction: () => Geolocator.openAppSettings(),
              ),
            ),
          if (_permissionState == _MapPermissionState.granted && _position == null) const _MapLoadingOverlay(message: 'Finding donors near you…'),

          if (_permissionState == _MapPermissionState.granted && _position != null) ...[
            Positioned(
              right: 16,
              bottom: MediaQuery.of(context).size.height * _sheetExtent + 16,
              child: _myLocationButton(),
            ),
            _donorSheet(),
          ],
        ],
      ),
    );
  }

  /// The floating recenter control every map app trains users to expect
  /// (Google Maps' bottom-right "my location" button) — tracks the sheet's
  /// drag extent so it never sits underneath it.
  Widget _myLocationButton() {
    return GestureDetector(
      onTap: _recenter,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.18), blurRadius: 10, offset: const Offset(0, 3))],
        ),
        alignment: Alignment.center,
        child: _recentering
            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary))
            : const Icon(LucideIcons.locateFixed, size: 20, color: AppColors.primary),
      ),
    );
  }

  /// The final artifact's "draggable sheet" — a real [DraggableScrollableSheet]
  /// rather than a fixed-height panel, so it behaves the way the design note
  /// ("the sheet actually drags") describes.
  Widget _donorSheet() {
    return DraggableScrollableSheet(
      controller: _sheetController,
      initialChildSize: 0.42,
      minChildSize: 0.16,
      maxChildSize: 0.85,
      snap: true,
      snapSizes: const [0.16, 0.42, 0.85],
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.only(topLeft: Radius.circular(22), topRight: Radius.circular(22)),
            boxShadow: [BoxShadow(color: AppColors.shadowCard.withValues(alpha: 0.12), blurRadius: 24, offset: const Offset(0, -8))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  margin: const EdgeInsets.symmetric(vertical: 9),
                  decoration: BoxDecoration(color: AppColors.warmBorder, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              Expanded(
                child: StreamBuilder<List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
                  key: ValueKey('list$_nearbyKey'),
                  stream: _donorStream,
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(
                        child: StateCard.error(
                          title: "Couldn't load donors",
                          message: 'Check your connection and try again.',
                          onRetry: () => setState(() => _retryToken++),
                        ),
                      );
                    }
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
                    }
                    final myUid = Backend.instance.currentUser?.uid;
                    final donors = snapshot.data!
                        .where((d) => d.id != myUid)
                        .map(_donorCardData)
                        .where((d) => _bloodGroupFilter == 'All' || d['bloodGroup'] == _bloodGroupFilter)
                        .where((d) => (d['distanceKm'] as double?) == null || (d['distanceKm'] as double) <= _searchRadiusKm)
                        .toList()
                      ..sort((a, b) {
                        final da = a['distanceKm'] as double?;
                        final db = b['distanceKm'] as double?;
                        if (da == null && db == null) return 0;
                        if (da == null) return 1;
                        if (db == null) return -1;
                        return da.compareTo(db);
                      });

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(left: 20, right: 20, bottom: 10),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text('Nearby donors', style: AppTextStyles.display(fontSize: 19, color: AppColors.ink)),
                              const SizedBox(width: 8),
                              Text('· ${donors.length} available', style: const TextStyle(fontSize: 12.5, color: AppColors.ink2)),
                              const Spacer(),
                              const Text('Nearest', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.red700)),
                            ],
                          ),
                        ),
                        Expanded(
                          child: donors.isEmpty
                              ? Center(
                                  child: StateCard.empty(
                                    icon: LucideIcons.mapPin,
                                    title: 'No available donors nearby yet. Try expanding your search radius.',
                                  ),
                                )
                              : ListView.separated(
                                  controller: scrollController,
                                  padding: EdgeInsets.fromLTRB(20, 8, 20, 8 + MediaQuery.of(context).padding.bottom),
                                  itemCount: donors.length,
                                  separatorBuilder: (context, index) => const SizedBox(height: 10),
                                  itemBuilder: (context, index) => _buildDonorCard(donors[index]),
                                ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _floatingCircleButton({required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.cardBorderWarm),
          boxShadow: [BoxShadow(color: AppColors.shadowCard, blurRadius: 10, offset: const Offset(0, 3))],
        ),
        child: Icon(icon, size: 18, color: AppColors.textPrimaryWarm),
      ),
    );
  }

  Widget _searchBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.controlRadius),
        border: Border.all(color: AppColors.cardBorderWarm),
        boxShadow: [BoxShadow(color: AppColors.shadowCard, blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 48,
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              style: const TextStyle(fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Search location',
                prefixIcon: const Icon(LucideIcons.search, size: 19, color: AppColors.textSecondary),
                suffixIcon: _searching
                    ? const Padding(padding: EdgeInsets.all(14), child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)))
                    : (_searchedLabel != null
                        ? IconButton(icon: const Icon(LucideIcons.x, size: 18, color: AppColors.textSecondary), onPressed: _clearSearch)
                        : null),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                isCollapsed: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
              ),
            ),
          ),
          if (_suggestions.isNotEmpty) ...[
            const Divider(height: 1),
            for (final suggestion in _suggestions)
              ListTile(
                dense: true,
                leading: const Icon(LucideIcons.mapPin, size: 16, color: AppColors.textSecondary),
                title: Text(suggestion['label'] as String, style: const TextStyle(fontSize: 12.5), maxLines: 2, overflow: TextOverflow.ellipsis),
                onTap: () => _pickLocation(suggestion),
              ),
          ],
        ],
      ),
    );
  }

  /// Avatar-disc marker per the final artifact ("Markers are the identity
  /// disc"): the donor's initials disc carries a group droplet badge and a
  /// small pointer tail. The nearest donor renders solid/larger; the rest
  /// sit tinted and smaller — the same emphasis falloff as the ring field.
  Widget _buildMapPin(Map<String, dynamic> donor, {required bool primary}) {
    final isHighlighted = _highlightedDonorId == donor['id'];
    final size = primary ? 56.0 : 44.0;
    final isAvailable = donor['isAvailable'] as bool;

    return GestureDetector(
      onTap: () => setState(() => _highlightedDonorId = donor['id'] as String),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: primary ? AppColors.primary : AppColors.primaryLightTint,
                  border: Border.all(color: Colors.white, width: isHighlighted ? 3 : 2.5),
                  boxShadow: [BoxShadow(color: AppColors.shadowHero, blurRadius: 10, offset: const Offset(0, 4))],
                ),
                alignment: Alignment.center,
                child: Text(
                  donor['initials'] as String,
                  style: TextStyle(color: primary ? AppColors.whiteTextOnPrimary : AppColors.primary, fontSize: primary ? 15 : 12, fontWeight: FontWeight.w600),
                ),
              ),
              Positioned(
                right: -6,
                top: -6,
                child: BloodGroupDroplet(label: donor['bloodGroup'] as String, size: primary ? 24 : 20, filled: true, color: AppColors.primary, textColor: AppColors.onEmber, fontSize: 8),
              ),
              if (!primary)
                Positioned(
                  right: -1,
                  bottom: -1,
                  child: Container(
                    width: 11,
                    height: 11,
                    decoration: BoxDecoration(
                      color: isAvailable ? AppColors.warmGreenText : AppColors.textMuted,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                ),
            ],
          ),
          CustomPaint(size: const Size(14, 7), painter: _MarkerTailPainter(color: Colors.white)),
        ],
      ),
    );
  }

  Widget _buildDonorCard(Map<String, dynamic> donor) {
    final bool isAvailable = donor['isAvailable'] as bool;
    final bool isVerified = donor['isVerified'] as bool;
    final isHighlighted = _highlightedDonorId == donor['id'];
    final distanceKmValue = donor['distanceKm'] as double?;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isHighlighted ? AppColors.primary : AppColors.cardBorderWarm, width: isHighlighted ? 1.5 : 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.primaryLightTint),
                    alignment: Alignment.center,
                    child: Text(donor['initials'] as String, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.primary)),
                  ),
                  Positioned(
                    right: -5,
                    bottom: -3,
                    child: BloodGroupDroplet(label: donor['bloodGroup'] as String, size: 20, filled: true, color: AppColors.primary, textColor: AppColors.onEmber, fontSize: 7),
                  ),
                ],
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(child: Text(donor['name'] as String, style: AppTextStyles.display(fontSize: 16, color: AppColors.ink), overflow: TextOverflow.ellipsis)),
                        if (isVerified) ...[
                          const SizedBox(width: 7),
                          Container(
                            width: 16,
                            height: 16,
                            decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.warmGreenBg),
                            alignment: Alignment.center,
                            child: const Icon(LucideIcons.check, color: AppColors.warmGreenText, size: 9),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Text(distanceKmValue == null ? 'Distance unknown' : '${distanceKmValue.toStringAsFixed(1)} km', style: const TextStyle(fontSize: 12.5, color: AppColors.ink2)),
                        const SizedBox(width: 7),
                        Container(width: 3, height: 3, decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.disabledTint)),
                        const SizedBox(width: 7),
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(shape: BoxShape.circle, color: isAvailable ? AppColors.warmGreenText : AppColors.textMuted),
                        ),
                        const SizedBox(width: 6),
                        Text(isAvailable ? 'Available' : 'Unavailable', style: const TextStyle(fontSize: 12.5, color: AppColors.ink2)),
                      ],
                    ),
                    if ((donor['area'] as String).isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(LucideIcons.mapPin, size: 11, color: AppColors.ink2),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(donor['area'] as String, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: AppColors.ink2)),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              if (isHighlighted)
                GestureDetector(
                  onTap: _sendingDonorId == null ? () => _sendRequestTo(donor) : null,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                    decoration: BoxDecoration(
                      color: _sendingDonorId == null ? AppColors.brandRed : AppColors.disabledTint,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: _sendingDonorId == donor['id']
                        ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Request', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppColors.whiteTextOnPrimary)),
                  ),
                )
              else
                GestureDetector(
                  onTap: () => setState(() => _highlightedDonorId = donor['id'] as String),
                  child: const Icon(LucideIcons.chevronRight, size: 18, color: AppColors.disabledTint),
                ),
            ],
          ),
          if (isHighlighted) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => DonorDetailsScreen(
                      donorId: donor['id'] as String,
                      name: donor['name'] as String,
                      initials: donor['initials'] as String,
                      bloodGroup: donor['bloodGroup'] as String,
                      isVerified: isVerified,
                      distanceKm: distanceKmValue,
                      isAvailable: isAvailable,
                    ),
                  ),
                ),
                child: const Text('View profile'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Map<String, dynamic> _donorCardData(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final name = data['name'] as String? ?? 'Donor';
    final initials = name.trim().isEmpty ? '?' : name.trim().split(RegExp(r'\s+')).take(2).map((w) => w[0].toUpperCase()).join();
    final lat = (data['lat'] as num?)?.toDouble();
    final lng = (data['lng'] as num?)?.toDouble();
    final km = (_position != null && lat != null && lng != null) ? distanceKm(_position!.latitude, _position!.longitude, lat, lng) : null;

    return {
      'id': doc.id,
      'name': name,
      'initials': initials,
      'bloodGroup': data['blood_group'] as String? ?? '',
      'isVerified': data['is_verified'] as bool? ?? false,
      'isAvailable': data['is_available'] as bool? ?? false,
      'lat': lat,
      'lng': lng,
      'distanceKm': km,
      'area': data['area'] as String? ?? '',
    };
  }
}

class _MapLoadingOverlay extends StatelessWidget {
  final String message;

  const _MapLoadingOverlay({required this.message});

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Container(
        color: AppColors.warmPageBackground.withValues(alpha: 0.9),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(strokeWidth: 3, color: AppColors.primary),
              const SizedBox(height: 12),
              Text(message, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textSecondary)),
            ],
          ),
        ),
      ),
    );
  }
}

class _MapOverlay extends StatelessWidget {
  final Widget child;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  const _MapOverlay({required this.child, this.secondaryLabel, this.onSecondary});

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Container(
        color: AppColors.warmPageBackground.withValues(alpha: 0.98),
        padding: const EdgeInsets.symmetric(horizontal: 30),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              child,
              if (secondaryLabel != null) ...[
                const SizedBox(height: 4),
                TextButton(onPressed: onSecondary, child: Text(secondaryLabel!)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Small downward-pointing tail beneath an avatar-disc map marker.
class _MarkerTailPainter extends CustomPainter {
  final Color color;
  const _MarkerTailPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width / 2 - 7, 0)
      ..lineTo(size.width / 2 + 7, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _MarkerTailPainter oldDelegate) => oldDelegate.color != color;
}
