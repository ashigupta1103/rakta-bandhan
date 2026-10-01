import 'dart:async';

import 'package:firebase_core/firebase_core.dart' show FirebaseException;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../services/backend.dart';
import 'location_picker_screen.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/blood_group_droplet.dart';
import 'consent_screen.dart';
import 'login_screen.dart';

class RegistrationScreen extends StatefulWidget {
  /// Pre-fills the mobile field when known (preview gallery); the email
  /// sign-in flow leaves it empty for the donor to type.
  final String phoneNumber;

  const RegistrationScreen({super.key, this.phoneNumber = ''});

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _whatsappController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();

  String? _selectedBloodGroup;

  String? _nameError;
  String? _whatsappError;
  String? _bloodGroupError;
  bool _isSubmitting = false;

  List<Map<String, dynamic>> _addressSuggestions = [];
  double? _selectedLat;
  double? _selectedLng;
  bool _searchingAddress = false;
  bool _locatingCurrent = false;
  Timer? _addressDebounce;

  final List<String> _bloodGroups = [
    'A+',
    'A-',
    'B+',
    'B-',
    'O+',
    'O-',
    'AB+',
    'AB-',
  ];

  @override
  void initState() {
    super.initState();
    _whatsappController.text = widget.phoneNumber;
    _useCurrentLocation(silent: true);
  }

  /// Same "detect and pre-fill" pattern as create_request_screen.dart —
  /// Uber/Rapido-style: the field opens with your actual current address
  /// already in it, editable/replaceable via search.
  Future<void> _useCurrentLocation({bool silent = false}) async {
    if (!silent) setState(() => _locatingCurrent = true);
    try {
      // Real GPS only — a donor's registered area decides which requests
      // reach them, so a guessed city here would silently break matching.
      final position = await Backend.instance.preciseLocation();
      if (position == null) {
        if (!mounted) return;
        setState(() => _locatingCurrent = false);
        if (!silent) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Couldn’t get your GPS location. Search for your area or pin it on the map.'),
          ));
        }
        return;
      }
      final label = await Backend.instance.reverseGeocode(
        position.latitude,
        position.longitude,
      );
      if (!mounted) return;
      setState(() {
        _selectedLat = position.latitude;
        _selectedLng = position.longitude;
        _locationController.text = label ?? 'Current location';
        _locatingCurrent = false;
        _addressSuggestions = [];
      });
    } catch (_) {
      if (mounted) setState(() => _locatingCurrent = false);
    }
  }

  Future<void> _pinOnMap() async {
    final picked = await LocationPickerScreen.open(
      context,
      title: 'Where do you usually live or work?',
      confirmLabel: 'Use this area',
      initialLat: _selectedLat,
      initialLng: _selectedLng,
    );
    if (picked == null || !mounted) return;
    setState(() {
      _selectedLat = picked.lat;
      _selectedLng = picked.lng;
      _locationController.text = picked.label;
      _addressSuggestions = [];
    });
  }

  @override
  void dispose() {
    _addressDebounce?.cancel();
    _nameController.dispose();
    _whatsappController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  void _onLocationChanged(String value) {
    _selectedLat = null;
    _selectedLng = null;
    _addressDebounce?.cancel();
    if (value.trim().length < 3) {
      setState(() => _addressSuggestions = []);
      return;
    }
    _addressDebounce = Timer(const Duration(milliseconds: 400), () async {
      setState(() => _searchingAddress = true);
      final results = await Backend.instance.searchAddress(value);
      if (!mounted) return;
      setState(() {
        _addressSuggestions = results;
        _searchingAddress = false;
      });
    });
  }

  void _pickAddress(Map<String, dynamic> suggestion) {
    setState(() {
      _locationController.text = suggestion['label'] as String;
      _selectedLat = suggestion['lat'] as double;
      _selectedLng = suggestion['lng'] as double;
      _addressSuggestions = [];
    });
  }

  Future<void> _handleRegister() async {
    final name = _nameController.text.trim();
    final whatsapp = _whatsappController.text.trim();

    setState(() {
      _nameError = name.isEmpty ? 'Name is required' : null;
      _whatsappError = whatsapp.isEmpty
          ? 'Mobile number is required'
          : !RegExp(r'^[6-9]\d{9}$').hasMatch(whatsapp)
              ? 'Enter a valid 10-digit Indian mobile number'
              : null;
      _bloodGroupError = _selectedBloodGroup == null
          ? 'Please select a blood group'
          : null;
    });

    if (_nameError != null || _whatsappError != null || _bloodGroupError != null) return;

    setState(() => _isSubmitting = true);
    try {
      double lat, lng;
      if (_selectedLat != null && _selectedLng != null) {
        lat = _selectedLat!;
        lng = _selectedLng!;
      } else {
        final position = await Backend.instance.preciseLocation();
        if (position == null) {
          if (!mounted) return;
          setState(() => _isSubmitting = false);
          await _pinOnMap();
          return;
        }
        lat = position.latitude;
        lng = position.longitude;
      }
      await Backend.instance.registerDonor(
        name: name,
        phone: whatsapp,
        bloodGroup: _selectedBloodGroup!,
        lat: lat,
        lng: lng,
        locationLabel: _locationController.text.trim(),
      );
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const ConsentScreen()),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Registration failed. ${_diagnosticSuffix(e)}Please try again.',
          ),
        ),
      );
    }
  }

  /// A short, safe diagnostic fragment appended to the failure message —
  /// this is a frontend-visibility improvement only (so a screenshot or a
  /// teammate reading over your shoulder can see *what kind* of failure
  /// this is without a dev console), not a fix to whatever the underlying
  /// cause turns out to be. Never echoes raw exception text — only the
  /// stable `code`/`type` fields exceptions expose for exactly this
  /// purpose.
  String _diagnosticSuffix(Object e) {
    if (e is FirebaseException) return '(${e.plugin}/${e.code}) ';
    return '(${e.runtimeType}) ';
  }

  // This screen is usually reached via Navigator.pushAndRemoveUntil right
  // after the sign-in code is accepted (see login_code_screen.dart) — it is the
  // new stack root with nothing beneath it. A plain Navigator.pop() here
  // would empty the Navigator and leave a black screen, so backing out
  // signs out and returns to the sign-in screen instead.
  bool _backHandled = false;
  Future<void> _handleBack() async {
    if (_backHandled) return;
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
      return;
    }
    _backHandled = true;
    try {
      await Backend.instance.signOut();
    } catch (_) {
      // Offline (or no Firebase at all, in widget tests) — still leave.
    }
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          return;
        }
        _handleBack();
      },
      child: Scaffold(
        backgroundColor: AppColors.warmPageBackground,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(
              LucideIcons.arrowLeft,
              color: AppColors.textPrimaryWarm,
            ),
            onPressed: _handleBack,
          ),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: 20.0,
              vertical: 8.0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Text(
                  'Complete registration',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.display(
                    fontSize: 22,
                    color: AppColors.textPrimaryWarm,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Provide details to complete your profile.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 32),

                // Name Field
                const Text(
                  'Full name',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimaryWarm,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _nameController,
                  style: Theme.of(context).textTheme.bodyLarge,
                  onChanged: (_) {
                    if (_nameError != null) setState(() => _nameError = null);
                  },
                  decoration: const InputDecoration(
                    hintText: 'Enter your name',
                  ),
                ),
                if (_nameError != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    _nameError!,
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: AppColors.primary),
                  ),
                ],
                const SizedBox(height: 24),

                // WhatsApp Field
                const Text(
                  'Mobile number (WhatsApp)',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimaryWarm,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _whatsappController,
                  keyboardType: TextInputType.phone,
                  style: Theme.of(context).textTheme.bodyLarge,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(10),
                  ],
                  onChanged: (_) {
                    if (_whatsappError != null) {
                      setState(() => _whatsappError = null);
                    }
                  },
                  decoration: const InputDecoration(
                    hintText: '10-digit mobile number',
                    prefixText: '+91  ',
                    helperText: 'Shared only with the person you are matched with.',
                  ),
                ),
                if (_whatsappError != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    _whatsappError!,
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: AppColors.primary),
                  ),
                ],
                const SizedBox(height: 24),

                // Location Field
                const Text(
                  'Location',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimaryWarm,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _locationController,
                  style: Theme.of(context).textTheme.bodyLarge,
                  onChanged: _onLocationChanged,
                  decoration: InputDecoration(
                    hintText: 'Search city or area',
                    suffixIcon: (_searchingAddress || _locatingCurrent)
                        ? const Padding(
                            padding: EdgeInsets.all(14),
                            child: SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : const Icon(LucideIcons.mapPin),
                  ),
                ),
                if (_addressSuggestions.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: AppColors.cardBorderWarm),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final suggestion in _addressSuggestions)
                          ListTile(
                            dense: true,
                            leading: const Icon(
                              LucideIcons.mapPin,
                              size: 16,
                              color: AppColors.textSecondary,
                            ),
                            title: Text(
                              suggestion['label'] as String,
                              style: Theme.of(context).textTheme.bodySmall,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            onTap: () => _pickAddress(suggestion),
                          ),
                      ],
                    ),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: GestureDetector(
                      onTap: _locatingCurrent
                          ? null
                          : () => _useCurrentLocation(),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            LucideIcons.mapPin,
                            size: 13,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _selectedLat != null
                                ? 'Location pinned · use current location again'
                                : 'Use current location',
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(width: 14),
                          GestureDetector(
                            onTap: _pinOnMap,
                            child: const Text(
                              'Pin on map',
                              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.primary, decoration: TextDecoration.underline, decorationColor: AppColors.red300),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 24),

                // Blood Group Grid
                const Text(
                  'Blood group',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimaryWarm,
                  ),
                ),
                const SizedBox(height: 8),

                // Blood group grid — droplet token, matching Create Request.
                GridView.count(
                  crossAxisCount: 4,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: 0.82,
                  children: [
                    for (final group in _bloodGroups)
                      GestureDetector(
                        onTap: () => setState(() {
                          _selectedBloodGroup = group;
                          _bloodGroupError = null;
                        }),
                        child: Center(
                          child: BloodGroupDroplet(
                            label: group,
                            size: 40,
                            filled: true,
                            color: _selectedBloodGroup == group
                                ? AppColors.primary
                                : AppColors.dividerWarm,
                            textColor: _selectedBloodGroup == group
                                ? AppColors.onEmber
                                : AppColors.textSecondary,
                            fontSize: 12,
                            serif: _selectedBloodGroup == group,
                          ),
                        ),
                      ),
                  ],
                ),
                if (_bloodGroupError != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _bloodGroupError!,
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: AppColors.primary),
                  ),
                ],
                const SizedBox(height: 40),

                // Complete Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _handleRegister,
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.whiteTextOnPrimary,
                            ),
                          )
                        : const Text('Complete registration'),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
