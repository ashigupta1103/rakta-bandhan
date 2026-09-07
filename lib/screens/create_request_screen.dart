import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../services/backend.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/blood_group_droplet.dart';
import '../widgets/loading_button.dart';
import 'matching_screen.dart';

enum _LocationState { idle, checking, denied, error }

/// Approved "Direction B" single-screen guided flow (Create Request
/// Options.dc.html — the 3-step wizard shown there is explicitly marked
/// REJECTED). Exactly one question is "live" (expanded, red-ring marker) at
/// a time; answering it collapses it to a green-check summary row and
/// reveals the next. All three answers stay visible and editable in place —
/// tapping a collapsed row re-expands it.
///
/// Deliberate deviation from the reference screenshots: the design's
/// canonical shot shows blood group already answered ("defaults from the
/// profile"), but a requester's own donor blood group is not necessarily
/// who the blood is needed for — auto-filling it would fabricate data, so
/// blood group has no default and is always the first live question here.
class CreateRequestScreen extends StatefulWidget {
  const CreateRequestScreen({super.key});

  @override
  State<CreateRequestScreen> createState() => _CreateRequestScreenState();
}

class _CreateRequestScreenState extends State<CreateRequestScreen> {
  static const _bloodGroups = ['A+', 'A-', 'B+', 'B-', 'O+', 'O-', 'AB+', 'AB-'];
  static const _urgencyOptions = [
    (id: 'normal', label: 'Normal', desc: 'Within a day or two', bars: 1),
    (id: 'urgent', label: 'Urgent', desc: 'Needed within hours', bars: 2),
    (id: 'critical', label: 'Critical', desc: 'Life-threatening — notify fastest', bars: 3),
  ];

  String? _bloodGroup;
  int _units = 1;
  String? _urgency;
  bool _locationEditing = false;
  final _locationController = TextEditingController();
  double? _selectedLat;
  double? _selectedLng;
  List<Map<String, dynamic>> _suggestions = [];
  bool _searching = false;
  Timer? _debounce;
  _LocationState _locationState = _LocationState.idle;

  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    // Approved flow pre-fills location from GPS when available — start the
    // lookup immediately so it's usually resolved by the time the location
    // question is reached, without blocking the group/urgency questions.
    _useCurrentLocation(silent: true);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _locationController.dispose();
    super.dispose();
  }

  void _onLocationChanged(String value) {
    _selectedLat = null;
    _selectedLng = null;
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

  void _pickAddress(Map<String, dynamic> suggestion) {
    setState(() {
      _locationController.text = suggestion['label'] as String;
      _selectedLat = suggestion['lat'] as double;
      _selectedLng = suggestion['lng'] as double;
      _suggestions = [];
      _locationState = _LocationState.idle;
      _locationEditing = false;
    });
  }

  Future<void> _useCurrentLocation({bool silent = false}) async {
    if (!silent) setState(() => _locationState = _LocationState.checking);
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        if (silent) return; // don't force a permission prompt on silent auto-init
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        if (mounted) setState(() => _locationState = _LocationState.denied);
        return;
      }
      final position = await Backend.instance.currentPosition();
      final label = await Backend.instance.reverseGeocode(position.latitude, position.longitude);
      if (!mounted) return;
      setState(() {
        _selectedLat = position.latitude;
        _selectedLng = position.longitude;
        _locationController.text = label ?? 'Current location';
        _locationState = _LocationState.idle;
        _locationEditing = false;
        _suggestions = [];
      });
    } on LocationServiceDisabledException {
      if (mounted && !silent) setState(() => _locationState = _LocationState.error);
    } catch (_) {
      if (mounted && !silent) setState(() => _locationState = _LocationState.error);
    }
  }

  bool get _locationResolved => _selectedLat != null && _selectedLng != null;
  bool get _canSubmit => _bloodGroup != null && _urgency != null && _locationController.text.trim().isNotEmpty;

  Future<void> _handleSubmit() async {
    if (!_canSubmit || _isSubmitting) return;
    setState(() => _isSubmitting = true);
    try {
      double lat, lng;
      if (_selectedLat != null && _selectedLng != null) {
        lat = _selectedLat!;
        lng = _selectedLng!;
      } else {
        final position = await Backend.instance.currentPosition();
        lat = position.latitude;
        lng = position.longitude;
      }
      final requestId = await Backend.instance.createRequest(
        bloodGroup: _bloodGroup!,
        unitsNeeded: _units,
        urgency: _urgency!,
        lat: lat,
        lng: lng,
        locationLabel: _locationController.text.trim(),
      );
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => MatchingScreen(requestId: requestId, bloodGroup: _bloodGroup!, urgency: _urgency!),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not send request. Please try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final groupAnswered = _bloodGroup != null;
    final urgencyAnswered = _urgency != null;
    // "Whole request visible throughout" (Create Request Options.dc.html's
    // own stated trade-off for this approved direction) — every question
    // stays on screen; only the current one gets the red-ring emphasis.
    final urgencyIsLive = groupAnswered && !urgencyAnswered;
    final locationIsLive = groupAnswered && urgencyAnswered && !_locationResolved;

    return Scaffold(
      backgroundColor: AppColors.warmPageBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft, color: AppColors.textPrimaryWarm),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('New request', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimaryWarm)),
        centerTitle: false,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(28, 4, 28, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Who needs blood?',
                      style: AppTextStyles.display(fontSize: 27, color: AppColors.textPrimaryWarm, height: 1.18),
                    ),

                    // ---- Q1: blood group ----
                    _questionDivider(),
                    if (!groupAnswered)
                      _questionSection(
                        label: 'BLOOD GROUP',
                        live: true,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _bloodGroupGrid(),
                            const SizedBox(height: 14),
                            _unitsStepper(),
                          ],
                        ),
                      )
                    else
                      _answeredRow(
                        label: 'BLOOD GROUP',
                        onTap: () => setState(() => _bloodGroup = null),
                        leading: BloodGroupDroplet(label: _bloodGroup!, size: 34, filled: true, color: AppColors.primary, textColor: const Color(0xFFFBE6E8), fontSize: 13, serif: true),
                        value: '$_units unit${_units == 1 ? '' : 's'}',
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _stepperButton(LucideIcons.minus, () => setState(() => _units = _units > 1 ? _units - 1 : 1)),
                            const SizedBox(width: 6),
                            _stepperButton(LucideIcons.plus, () => setState(() => _units = _units < 10 ? _units + 1 : 10)),
                          ],
                        ),
                      ),

                    // ---- Q2: urgency — always visible ("whole request
                    // visible throughout"), red ring only once it's the
                    // active question.
                    _questionDivider(),
                    if (!urgencyAnswered)
                      _questionSection(
                        label: 'HOW URGENT',
                        live: urgencyIsLive,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            for (final option in _urgencyOptions) ...[
                              _urgencyRow(option),
                              if (option != _urgencyOptions.last) const SizedBox(height: 9),
                            ],
                          ],
                        ),
                      )
                    else
                      _answeredRow(
                        label: 'HOW URGENT',
                        onTap: () => setState(() => _urgency = null),
                        value: '${_urgencyOptions.firstWhere((u) => u.id == _urgency).label} · ${_urgencyOptions.firstWhere((u) => u.id == _urgency).desc}',
                      ),

                    // ---- Q3: location — same always-visible treatment.
                    _questionDivider(),
                    _locationSection(live: locationIsLive),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 0, 28, 20),
              child: Column(
                children: [
                  LoadingButton(label: 'Alert nearby donors', isLoading: _isSubmitting, onPressed: _canSubmit ? _handleSubmit : null),
                  const SizedBox(height: 9),
                  Text(
                    _canSubmit ? 'Alerts nearby compatible donors' : 'Answer every question to continue',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------- Sections

  Widget _questionDivider() => Container(height: 1, color: AppColors.dividerWarm, margin: const EdgeInsets.symmetric(vertical: 20));

  /// A question that stays visible whether or not it's the active one — the
  /// red ring and red micro-label mark the single live question; a question
  /// waiting its turn renders identically but in the quiet neutral tone.
  Widget _questionSection({required String label, required bool live, required Widget child}) {
    final accent = live ? AppColors.primary : AppColors.borderStrong;
    final labelColor = live ? AppColors.primary : AppColors.textSecondary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(width: 18, height: 18, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: accent, width: 1.5))),
            const SizedBox(width: 11),
            Text(label, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, letterSpacing: 1.1, color: labelColor)),
          ],
        ),
        const SizedBox(height: 12),
        child,
      ],
    );
  }

  Widget _answeredRow({required String label, required VoidCallback onTap, Widget? leading, required String value, Widget? trailing}) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Row(
        children: [
          Container(
            width: 18,
            height: 18,
            decoration: const BoxDecoration(color: AppColors.warmGreenText, shape: BoxShape.circle),
            alignment: Alignment.center,
            child: const Icon(LucideIcons.check, size: 11, color: Colors.white),
          ),
          const SizedBox(width: 11),
          if (leading != null) ...[leading, const SizedBox(width: 12)],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, letterSpacing: 1.1, color: AppColors.textSecondary)),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppColors.textPrimaryWarm)),
              ],
            ),
          ),
          trailing ?? const Icon(LucideIcons.chevronRight, size: 15, color: AppColors.textSecondary),
        ],
      ),
    );
  }

  Widget _unitsStepper() {
    return Row(
      children: [
        const Text('Units', style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
        const Spacer(),
        _stepperButton(LucideIcons.minus, () => setState(() => _units = _units > 1 ? _units - 1 : 1)),
        SizedBox(width: 30, child: Text('$_units', textAlign: TextAlign.center, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimaryWarm))),
        _stepperButton(LucideIcons.plus, () => setState(() => _units = _units < 10 ? _units + 1 : 10)),
      ],
    );
  }

  Widget _stepperButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(color: Colors.white, border: Border.all(color: AppColors.dividerWarm), borderRadius: BorderRadius.circular(10)),
        alignment: Alignment.center,
        child: Icon(icon, size: 13, color: AppColors.textPrimaryWarm),
      ),
    );
  }

  Widget _bloodGroupGrid() {
    return GridView.count(
      crossAxisCount: 4,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 0.82,
      children: [
        for (final group in _bloodGroups)
          GestureDetector(
            onTap: () => setState(() => _bloodGroup = group),
            child: Center(
              child: BloodGroupDroplet(label: group, size: 40, filled: true, color: AppColors.dividerWarm, textColor: AppColors.textSecondary, fontSize: 12),
            ),
          ),
      ],
    );
  }

  Widget _urgencyRow(({String id, String label, String desc, int bars}) option) {
    return GestureDetector(
      onTap: () => setState(() => _urgency = option.id),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
        decoration: BoxDecoration(border: Border.all(color: AppColors.dividerWarm), borderRadius: BorderRadius.circular(15)),
        child: Row(
          children: [
            Container(width: 19, height: 19, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: AppColors.borderStrong, width: 1.5))),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(option.label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimaryWarm)),
                  Text(option.desc, style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _locationSection({required bool live}) {
    if (_locationResolved && !_locationEditing) {
      return _answeredRow(
        label: 'WHERE',
        onTap: () => setState(() => _locationEditing = true),
        leading: const Icon(LucideIcons.mapPin, size: 17, color: AppColors.textSecondary),
        value: _locationController.text,
      );
    }

    return _questionSection(
      label: 'WHERE',
      live: live,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_locationState == _LocationState.checking) ...[
            const Row(
              children: [
                SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
                SizedBox(width: 8),
                Text('Checking location access…', style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
              ],
            ),
            const SizedBox(height: 12),
          ],
          if (_locationState == _LocationState.denied) ...[
            const Text(
              "We can't read your location, so tell us where the blood is needed — donors are matched by distance from here.",
              style: TextStyle(fontSize: 13.5, color: AppColors.textSecondary, height: 1.6),
            ),
            const SizedBox(height: 12),
          ],
          if (_locationState == _LocationState.error) ...[
            Container(
              padding: const EdgeInsets.only(left: 14),
              decoration: const BoxDecoration(border: Border(left: BorderSide(color: AppColors.primary, width: 2))),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Couldn't find your location", style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppColors.textPrimaryWarm)),
                  SizedBox(height: 4),
                  Text('Your connection may have dropped. Try again, or enter the location yourself.', style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary, height: 1.5)),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(onPressed: () => _useCurrentLocation(), child: const Text('Try again')),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(foregroundColor: AppColors.textPrimaryWarm, side: const BorderSide(color: AppColors.dividerWarm)),
                    onPressed: () => setState(() {}),
                    child: const Text('Enter manually'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
          Container(
            decoration: BoxDecoration(border: Border.all(color: AppColors.dividerWarm), borderRadius: BorderRadius.circular(15), color: Colors.white),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: [
                const Icon(LucideIcons.mapPin, size: 16, color: AppColors.textSecondary),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _locationController,
                    onChanged: _onLocationChanged,
                    decoration: const InputDecoration(
                      hintText: 'Hospital, area or landmark',
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                if (_searching) const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
              ],
            ),
          ),
          if (_suggestions.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(top: 6),
              decoration: BoxDecoration(color: Colors.white, border: Border.all(color: AppColors.dividerWarm), borderRadius: BorderRadius.circular(14)),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final suggestion in _suggestions)
                    ListTile(
                      dense: true,
                      leading: const Icon(LucideIcons.mapPin, size: 16, color: AppColors.textSecondary),
                      title: Text(suggestion['label'] as String, style: const TextStyle(fontSize: 12.5), maxLines: 2, overflow: TextOverflow.ellipsis),
                      onTap: () => _pickAddress(suggestion),
                    ),
                ],
              ),
            ),
          if (_locationState != _LocationState.denied && _locationState != _LocationState.error) ...[
            const SizedBox(height: 10),
            GestureDetector(
              onTap: () => _useCurrentLocation(),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(LucideIcons.mapPin, size: 13, color: AppColors.primary),
                  SizedBox(width: 6),
                  Text('Use current location', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.primary)),
                ],
              ),
            ),
          ],
          if (_locationState == _LocationState.denied) ...[
            const SizedBox(height: 4),
            GestureDetector(
              onTap: () => _useCurrentLocation(),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(LucideIcons.mapPin, size: 13, color: AppColors.primary),
                  SizedBox(width: 6),
                  Text('Turn on location instead', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.primary)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
