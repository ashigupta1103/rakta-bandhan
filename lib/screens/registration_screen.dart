import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../services/backend.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/blood_group_droplet.dart';
import 'consent_screen.dart';

class RegistrationScreen extends StatefulWidget {
  final String phoneNumber;

  const RegistrationScreen({super.key, required this.phoneNumber});

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
    'A+', 'A-', 'B+', 'B-',
    'O+', 'O-', 'AB+', 'AB-'
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
      final position = await Backend.instance.currentPosition();
      final label = await Backend.instance.reverseGeocode(position.latitude, position.longitude);
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
      _whatsappError = whatsapp.isEmpty ? 'WhatsApp number is required' : null;
      _bloodGroupError = _selectedBloodGroup == null ? 'Please select a blood group' : null;
    });

    if (name.isEmpty || whatsapp.isEmpty || _selectedBloodGroup == null) return;

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
        const SnackBar(content: Text('Registration failed. Please try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.warmPageBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            LucideIcons.arrowLeft,
            color: AppColors.textPrimaryWarm,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Text(
                'Complete registration',
                textAlign: TextAlign.center,
                style: AppTextStyles.display(fontSize: 22, color: AppColors.textPrimaryWarm),
              ),
              const SizedBox(height: 8),
              const Text(
                'Provide details to complete your profile.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 32),

              // Name Field
              const Text(
                'Full name',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimaryWarm),
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
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.primary,
                      ),
                ),
              ],
              const SizedBox(height: 24),

              // WhatsApp Field
              const Text(
                'WhatsApp number',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimaryWarm),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _whatsappController,
                keyboardType: TextInputType.phone,
                style: Theme.of(context).textTheme.bodyLarge,
                onChanged: (_) {
                  if (_whatsappError != null) setState(() => _whatsappError = null);
                },
                decoration: const InputDecoration(
                  hintText: 'Enter WhatsApp number',
                ),
              ),
              if (_whatsappError != null) ...[
                const SizedBox(height: 6),
                Text(
                  _whatsappError!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.primary,
                      ),
                ),
              ],
              const SizedBox(height: 24),

              // Location Field
              const Text(
                'Location',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimaryWarm),
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
                          leading: const Icon(LucideIcons.mapPin, size: 16, color: AppColors.textSecondary),
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
                    onTap: _locatingCurrent ? null : () => _useCurrentLocation(),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(LucideIcons.mapPin, size: 13, color: AppColors.primary),
                        const SizedBox(width: 6),
                        Text(
                          _selectedLat != null ? 'Location pinned · use current location again' : 'Use current location',
                          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.primary),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 24),

              // Blood Group Grid
              const Text(
                'Blood group',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimaryWarm),
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
                          color: _selectedBloodGroup == group ? AppColors.primary : AppColors.dividerWarm,
                          textColor: _selectedBloodGroup == group ? const Color(0xFFFBE6E8) : AppColors.textSecondary,
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
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.primary,
                      ),
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
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.whiteTextOnPrimary),
                        )
                      : const Text('Complete registration'),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
