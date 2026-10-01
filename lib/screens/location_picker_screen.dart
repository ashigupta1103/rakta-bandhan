import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gm;
import 'package:latlong2/latlong.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../services/backend.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/map_tiles.dart';
import '../widgets/pressable.dart';

@immutable
class PickedLocation {
  final double lat;
  final double lng;
  final String label;
  const PickedLocation({required this.lat, required this.lng, required this.label});
}

/// Rapido/Uber-style exact location picker.
///
/// The pin never moves — the map moves under it, so the point is exactly
/// where the user puts it (building-level), not wherever an address search
/// happened to geocode. While the map is being dragged the pin lifts and
/// the address line says "Move the map…"; ~450 ms after it settles, the
/// address under the pin is looked up and shown. "Locate me" flies to the
/// real GPS fix and draws its accuracy circle, so the user can see how much
/// to trust it. Search jumps the map; the pin still has the final word.
///
/// On phones built with Google Maps (kUseGoogleMaps) the map is the native
/// Google map — the same streets and landmarks people know from ride apps;
/// otherwise flutter_map. The pin logic is identical for both.
///
/// Returns a [PickedLocation] via Navigator.pop, or null if dismissed.
class LocationPickerScreen extends StatefulWidget {
  final String title;
  final String confirmLabel;
  final double? initialLat;
  final double? initialLng;

  const LocationPickerScreen({
    super.key,
    this.title = 'Set the exact location',
    this.confirmLabel = 'Confirm location',
    this.initialLat,
    this.initialLng,
  });

  static Future<PickedLocation?> open(
    BuildContext context, {
    String title = 'Set the exact location',
    String confirmLabel = 'Confirm location',
    double? initialLat,
    double? initialLng,
  }) =>
      Navigator.of(context).push<PickedLocation>(MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => LocationPickerScreen(title: title, confirmLabel: confirmLabel, initialLat: initialLat, initialLng: initialLng),
      ));

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  final _map = MapController();
  gm.GoogleMapController? _gmap;
  final _search = TextEditingController();
  Timer? _settle;
  Timer? _searchDebounce;

  LatLng? _center;
  Position? _gps;
  bool _dragging = false;
  bool _resolving = false;
  bool _locating = false;
  String? _address;
  List<Map<String, dynamic>> _results = [];
  bool _searching = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialLat != null && widget.initialLng != null) {
      _center = LatLng(widget.initialLat!, widget.initialLng!);
    }
    // Both paths call setState, which isn't allowed until after initState.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_center != null) {
        _resolve(_center!);
      } else {
        _locate(initial: true);
      }
    });
  }

  @override
  void dispose() {
    _settle?.cancel();
    _searchDebounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _locate({bool initial = false}) async {
    setState(() => _locating = true);
    final p = await Backend.instance.preciseLocation();
    if (!mounted) return;
    setState(() => _locating = false);
    if (p == null) {
      if (initial) {
        // Open somewhere sensible, but say so — never pretend it's them.
        final fallback = await Backend.instance.currentPosition();
        if (!mounted) return;
        setState(() => _center = LatLng(fallback.latitude, fallback.longitude));
      }
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Couldn’t get your GPS location. Search for the place, or move the map to it.'),
      ));
      return;
    }
    final here = LatLng(p.latitude, p.longitude);
    setState(() {
      _gps = p;
      _center ??= here;
    });
    if (!initial) _moveTo(here, 17.5);
    _resolve(here);
  }

  void _moveTo(LatLng at, double zoom) {
    if (useGoogleMaps) {
      _gmap?.animateCamera(gm.CameraUpdate.newLatLngZoom(gm.LatLng(at.latitude, at.longitude), zoom));
    } else {
      _map.move(at, zoom);
    }
  }

  /// Called continuously while the map moves (either map engine).
  void _onCenterMoved(LatLng center) {
    _center = center;
    if (!_dragging) setState(() => _dragging = true);
    _settle?.cancel();
    _settle = Timer(const Duration(milliseconds: 450), () {
      if (!mounted) return;
      setState(() => _dragging = false);
      HapticFeedback.selectionClick();
      _resolve(center);
    });
  }

  Widget _googleMap(LatLng center) {
    final gps = _gps;
    return gm.GoogleMap(
      initialCameraPosition: gm.CameraPosition(target: gm.LatLng(center.latitude, center.longitude), zoom: 17.5),
      onMapCreated: (c) => _gmap = c,
      onCameraMove: (pos) => _onCenterMoved(LatLng(pos.target.latitude, pos.target.longitude)),
      myLocationEnabled: gps != null,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      mapToolbarEnabled: false,
      compassEnabled: false,
      rotateGesturesEnabled: false,
      tiltGesturesEnabled: false,
      minMaxZoomPreference: const gm.MinMaxZoomPreference(4, 20),
      circles: {
        if (gps != null)
          gm.Circle(
            circleId: const gm.CircleId('gps-accuracy'),
            center: gm.LatLng(gps.latitude, gps.longitude),
            radius: gps.accuracy.clamp(5, 500).toDouble(),
            fillColor: AppColors.gpsAccuracyFill,
            strokeColor: AppColors.gpsAccuracyBorder,
            strokeWidth: 1,
          ),
      },
    );
  }

  Future<void> _resolve(LatLng at) async {
    setState(() => _resolving = true);
    final label = await Backend.instance.reverseGeocode(at.latitude, at.longitude);
    if (!mounted) return;
    // Ignore a slow answer for a spot the user has already moved away from.
    if (_center != null && (_center!.latitude - at.latitude).abs() > 1e-6) return;
    setState(() {
      _resolving = false;
      _address = label;
    });
  }

  void _onSearchChanged(String q) {
    _searchDebounce?.cancel();
    if (q.trim().length < 3) {
      setState(() => _results = []);
      return;
    }
    _searchDebounce = Timer(const Duration(milliseconds: 450), () async {
      setState(() => _searching = true);
      final c = _center;
      final results = await Backend.instance.searchAddress(q, near: c == null ? null : (lat: c.latitude, lng: c.longitude));
      if (!mounted) return;
      setState(() {
        _results = results;
        _searching = false;
      });
    });
  }

  void _pickResult(Map<String, dynamic> r) {
    final at = LatLng(r['lat'] as double, r['lng'] as double);
    FocusScope.of(context).unfocus();
    setState(() {
      _results = [];
      _search.clear();
      _center = at;
      _address = r['label'] as String;
    });
    _moveTo(at, 17.5);
  }

  void _confirm() {
    final c = _center;
    if (c == null) return;
    // Never store raw coordinates as the place name — they'd show up on
    // request cards and notifications.
    final label = (_address == null || _address!.trim().isEmpty) ? 'Pinned location' : _address!;
    Navigator.of(context).pop(PickedLocation(lat: c.latitude, lng: c.longitude, label: label));
  }

  @override
  Widget build(BuildContext context) {
    final center = _center;
    return Scaffold(
      backgroundColor: AppColors.mapBase,
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          if (center != null && useGoogleMaps)
            _googleMap(center)
          else if (center != null)
            FlutterMap(
              mapController: _map,
              options: MapOptions(
                initialCenter: center,
                initialZoom: 17.5,
                minZoom: 4,
                maxZoom: 19,
                interactionOptions: const InteractionOptions(flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
                onPositionChanged: (camera, _) => _onCenterMoved(camera.center),
              ),
              children: [
                ...appMapBase(),
                if (_gps != null)
                  CircleLayer(circles: [
                    CircleMarker(
                      point: LatLng(_gps!.latitude, _gps!.longitude),
                      radius: _gps!.accuracy.clamp(5, 500).toDouble(),
                      useRadiusInMeter: true,
                      color: AppColors.gpsAccuracyFill,
                      borderColor: AppColors.gpsAccuracyBorder,
                      borderStrokeWidth: 1,
                    ),
                  ]),
                if (_gps != null)
                  MarkerLayer(markers: [
                    Marker(
                      point: LatLng(_gps!.latitude, _gps!.longitude),
                      width: 18,
                      height: 18,
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.gpsDot,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: const [BoxShadow(color: AppColors.mapPinShadow, blurRadius: 4)],
                        ),
                      ),
                    ),
                  ]),
                appMapAttribution(),
              ],
            )
          else
            const Center(child: CircularProgressIndicator(strokeWidth: 2)),

          // The fixed centre pin — the map moves, the pin doesn't.
          if (center != null) IgnorePointer(child: Center(child: _CenterPin(lifted: _dragging))),

          // Top: back + search.
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Column(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: const [BoxShadow(color: AppColors.shadowHero, blurRadius: 18, offset: Offset(0, 6))],
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          tooltip: 'Back',
                          icon: const Icon(LucideIcons.arrowLeft, size: 20, color: AppColors.ink),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                        Expanded(
                          child: TextField(
                            controller: _search,
                            onChanged: _onSearchChanged,
                            textInputAction: TextInputAction.search,
                            style: const TextStyle(fontSize: 15, color: AppColors.ink),
                            decoration: const InputDecoration(
                              hintText: 'Search hospital, area or landmark',
                              filled: false,
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(vertical: 14),
                            ),
                          ),
                        ),
                        if (_searching)
                          const Padding(padding: EdgeInsets.all(14), child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)))
                        else
                          const SizedBox(width: 12),
                      ],
                    ),
                  ),
                  if (_results.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(top: 6),
                      constraints: const BoxConstraints(maxHeight: 300),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.warmBorder)),
                      child: ListView.separated(
                        shrinkWrap: true,
                        padding: EdgeInsets.zero,
                        itemCount: _results.length,
                        separatorBuilder: (_, _) => const Divider(height: 1, color: AppColors.warmDivider),
                        itemBuilder: (_, i) => ListTile(
                          dense: true,
                          leading: const Icon(LucideIcons.mapPin, size: 17, color: AppColors.ink2),
                          title: Text(_results[i]['label'] as String, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13.5, color: AppColors.ink)),
                          onTap: () => _pickResult(_results[i]),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Bottom: locate-me + address card + confirm.
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 14, bottom: 12),
                  child: Pressable(
                    onTap: _locating ? null : () => _locate(),
                    semanticLabel: 'Go to my location',
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: AppColors.shadowHero, blurRadius: 14, offset: Offset(0, 4))],
                      ),
                      alignment: Alignment.center,
                      child: _locating
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(LucideIcons.locateFixed, size: 20, color: AppColors.brandRed),
                    ),
                  ),
                ),
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.fromLTRB(20, 18, 20, 16 + MediaQuery.paddingOf(context).bottom),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                    boxShadow: [BoxShadow(color: AppColors.shadowHero, blurRadius: 24, offset: Offset(0, -4))],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(widget.title, style: AppTextStyles.display(fontSize: 19, color: AppColors.ink)),
                      const SizedBox(height: 10),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(padding: EdgeInsets.only(top: 2), child: Icon(LucideIcons.mapPin, size: 17, color: AppColors.brandRed)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 160),
                              child: Text(
                                _dragging
                                    ? 'Move the map to place the pin exactly…'
                                    : _resolving
                                        ? 'Finding the address…'
                                        : (_address ?? 'Address not found — the pin position is still exact'),
                                key: ValueKey('$_dragging$_resolving$_address'),
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 14, height: 1.4, color: _dragging || _resolving ? AppColors.ink2 : AppColors.ink),
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (_gps != null && !_dragging) ...[
                        const SizedBox(height: 6),
                        Text(
                          'GPS accurate to about ${_gps!.accuracy.round()} m · the pin is what we save',
                          style: const TextStyle(fontSize: 11.5, color: AppColors.mutedInk),
                        ),
                      ],
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: center == null || _dragging ? null : _confirm,
                        child: Text(widget.confirmLabel),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Brand pin: a red head with a white core on a short stem, and a ground
/// shadow. Lifts 10px (and the shadow shrinks) while the map is moving —
/// the "I'm carrying the pin" cue every ride-hailing app uses.
class _CenterPin extends StatelessWidget {
  final bool lifted;
  const _CenterPin({required this.lifted});

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final lift = lifted && !reduce ? -10.0 : 0.0;
    // Pin tip sits exactly on the map centre: the widget is offset up by
    // its own height so its bottom point marks the spot.
    return Transform.translate(
      offset: const Offset(0, -30),
      child: SizedBox(
        width: 40,
        height: 60,
        child: Stack(
          alignment: Alignment.bottomCenter,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              curve: Curves.easeOut,
              width: lifted ? 8 : 14,
              height: lifted ? 3 : 5,
              margin: const EdgeInsets.only(bottom: 4),
              decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.28), borderRadius: BorderRadius.circular(8)),
            ),
            AnimatedSlide(
              duration: const Duration(milliseconds: 160),
              curve: Curves.easeOut,
              offset: Offset(0, lift / 60),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: AppColors.brandRed,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3),
                      boxShadow: const [BoxShadow(color: AppColors.mapPinShadow, blurRadius: 8, offset: Offset(0, 3))],
                    ),
                    alignment: Alignment.center,
                    child: Container(width: 10, height: 10, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
                  ),
                  Container(width: 3, height: 16, decoration: BoxDecoration(color: AppColors.brandRed, borderRadius: BorderRadius.circular(2))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
