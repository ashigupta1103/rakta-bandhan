import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../demo/demo.dart';
import '../services/backend.dart';
import 'location_picker_screen.dart';
import 'matching_screen.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../theme/app_theme.dart';
import '../widgets/blood_group_droplet.dart';
import '../widgets/identity_disc.dart';
import '../widgets/rb_ui.dart';
import '../widgets/loading_button.dart';
import '../widgets/rb_icon.dart';

/// Pre-match donor discovery screen — the final artifact's "Donor details"
/// section: "built around trust and disclosure". Deliberately has no
/// call or message actions — contact details are only real once a request is
/// accepted (see MatchContactScreen). Showing them here would be
/// fabricating access to sensitive donor information the donor hasn't
/// agreed to share yet.
///
/// Everything shown comes from the donor's public listing (`donors_public`):
/// group, availability, verification, neighbourhood and `updated_at`. There
/// is no donation count — other donors' fulfilled requests aren't readable
/// under the rules, so any count here would be invented.
class DonorDetailsScreen extends StatefulWidget {
  final String donorId;
  final String name;
  final String initials;
  final String bloodGroup;
  final bool isVerified;
  final double? distanceKm;
  final bool isAvailable;

  /// Opened from a match: this donor already accepted, so there is no
  /// "request" action.
  final bool matched;

  /// Donations recorded through the app, when the caller can actually know
  /// it. Other donors' history isn't readable under the rules, so real
  /// screens pass null and no number is shown; the client demo passes its
  /// persona's fixture.
  final int? donationCount;

  const DonorDetailsScreen({
    super.key,
    required this.donorId,
    required this.name,
    required this.initials,
    required this.bloodGroup,
    required this.isVerified,
    required this.distanceKm,
    required this.isAvailable,
    this.matched = false,
    this.donationCount,
  });

  @override
  State<DonorDetailsScreen> createState() => _DonorDetailsScreenState();
}

class _DonorDetailsScreenState extends State<DonorDetailsScreen> {
  bool _isSending = false;

  Future<void> _sendRequest() async {
    if (Demo.on) {
      Demo.instance.createRequest(group: widget.bloodGroup, units: 1, urgency: 'urgent', label: Demo.hospital);
      Navigator.push(context, MaterialPageRoute(builder: (_) => MatchingScreen(requestId: Demo.requestId, bloodGroup: widget.bloodGroup, urgency: 'urgent')));
      return;
    }
    setState(() => _isSending = true);
    try {
      // The request's location is where donors will travel — real GPS or
      // an explicit pin, never a guessed default.
      final pos = await Backend.instance.preciseLocation();
      double lat, lng;
      String label;
      if (pos != null) {
        lat = pos.latitude;
        lng = pos.longitude;
        label = await Backend.instance.reverseGeocode(lat, lng) ?? 'Requested via ${widget.name}\'s profile';
      } else {
        if (!mounted) return;
        final picked = await LocationPickerScreen.open(context, title: 'Where is the blood needed?', confirmLabel: 'Send request here');
        if (picked == null) {
          if (mounted) setState(() => _isSending = false);
          return;
        }
        lat = picked.lat;
        lng = picked.lng;
        label = picked.label;
      }
      await Backend.instance.createRequest(
        bloodGroup: widget.bloodGroup,
        unitsNeeded: 1,
        urgency: 'urgent',
        lat: lat,
        lng: lng,
        locationLabel: label,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Blood request sent — visible to nearby ${widget.bloodGroup} donors.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not send request. Please try again.')),
      );
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  /// The public listing: neighbourhood name and when it was last updated.
  /// Contact details are never read here.
  late final Future<Map<String, dynamic>?> _public = Demo.isDemoId(widget.donorId)
      ? Future.value({'area': Demo.area, 'updated_at': Timestamp.now()})
      : FirebaseFirestore.instance.collection('donors_public').doc(widget.donorId).get().then((s) => s.data());

  String _updatedLabel(Timestamp? updatedAt) {
    if (updatedAt == null) return '';
    final diff = DateTime.now().difference(updatedAt.toDate());
    if (diff.inHours < 24) return 'Profile updated today';
    if (diff.inDays < 7) return 'Profile updated ${diff.inDays}d ago';
    if (diff.inDays < 60) return 'Profile updated ${(diff.inDays / 7).floor()}w ago';
    return 'Profile updated ${(diff.inDays / 30).floor()} months ago';
  }

  @override
  Widget build(BuildContext context) {
    final firstName = widget.name.trim().split(RegExp(r'\s+')).first;
    final km = widget.distanceKm;
    return Scaffold(
      backgroundColor: AppColors.warmPageBackground,
      appBar: AppBar(
        backgroundColor: AppColors.warmPageBackground,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          tooltip: 'Back',
          icon: const RbIcon(RbGlyph.back, color: AppColors.textPrimaryWarm),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Donor profile', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: AppColors.textPrimaryWarm)),
        centerTitle: false,
      ),
      bottomNavigationBar: widget.matched ? null : SafeArea(
        minimum: const EdgeInsets.fromLTRB(20, 8, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.isAvailable) ...[
              LoadingButton(label: 'Request ${widget.bloodGroup} blood from $firstName', isLoading: _isSending, onPressed: _sendRequest),
              const SizedBox(height: 8),
              const Text('Nearby compatible donors are alerted in the app. No phone number is shared.',
                  textAlign: TextAlign.center, style: TextStyle(fontSize: 12.5, color: AppColors.ink2, height: 1.35)),
            ] else
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                decoration: BoxDecoration(color: AppColors.sand, borderRadius: BorderRadius.circular(AppTheme.controlRadius)),
                child: Text('$firstName isn’t accepting requests right now', textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: AppColors.ink2)),
              ),
          ],
        ),
      ),
      body: FutureBuilder<Map<String, dynamic>?>(
        future: _public,
        builder: (context, snapshot) {
          final pub = snapshot.data;
          final area = (pub?['area'] as String?)?.trim();
          final updatedAt = pub?['updated_at'] as Timestamp?;
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
            children: [
              RbCard(
                padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
                child: Column(
                  children: [
                    // Profile photos are private to their owner, so other
                    // people always see the initials disc.
                    IdentityDisc(
                      initials: widget.initials,
                      size: 88,
                      isPublic: true,
                      bloodGroup: widget.bloodGroup,
                    ),
                    const SizedBox(height: 14),
                    Text(widget.name, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.display(fontSize: 25, color: AppColors.ink, height: 1.15)),
                    const SizedBox(height: 10),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        RbChip(
                          widget.isVerified ? 'Verified donor' : 'Not yet verified',
                          icon: widget.isVerified ? RbGlyph.verified : RbGlyph.shield,
                          tone: widget.isVerified ? RbTone.success : RbTone.neutral,
                        ),
                        if (widget.matched)
                          const RbChip('Accepted your request', icon: RbGlyph.connect, tone: RbTone.red)
                        else
                        RbChip(
                          widget.isAvailable ? 'Available now' : 'Not available',
                          icon: widget.isAvailable ? RbGlyph.checkCircle : RbGlyph.clock,
                          tone: widget.isAvailable ? RbTone.success : RbTone.neutral,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _statTile(
                    BloodGroupDroplet(label: widget.bloodGroup, size: 34, fontSize: 11.5, serif: true),
                    'Blood group',
                  ),
                  const SizedBox(width: 10),
                  _statTile(
                    Text(km == null ? '—' : (km < 10 ? km.toStringAsFixed(1) : '${km.round()}'), style: AppTextStyles.display(fontSize: 24, color: AppColors.ink, height: 1.2)),
                    km == null ? 'Distance unknown' : 'km away',
                  ),
                  if (widget.donationCount != null) ...[
                    const SizedBox(width: 10),
                    _statTile(
                      Text('${widget.donationCount}', style: AppTextStyles.display(fontSize: 24, color: AppColors.ink, height: 1.2)),
                      widget.donationCount == 1 ? 'donation' : 'donations',
                    ),
                  ],
                ],
              ),
              if (widget.donationCount != null && widget.donationCount! > 0) ...[
                const SizedBox(height: 14),
                Text(
                  '$firstName has donated ${widget.donationCount == 1 ? 'once' : '${widget.donationCount} times'} through Rakta Bandhan.',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.display(fontSize: 16, color: AppColors.ink2, height: 1.4),
                ),
              ],
              const RbSectionLabel('About this donor'),
              RbListGroup(
                children: [
                  RbRow(
                    icon: RbGlyph.pin,
                    title: snapshot.connectionState == ConnectionState.waiting
                        ? 'Loading area…'
                        : (area == null || area.isEmpty ? 'Area not shared' : 'Approx. area: $area'),
                    subtitle: 'Shown to about 1 km — never an exact address',
                  ),
                  RbRow(
                    icon: RbGlyph.droplet,
                    title: '${widget.bloodGroup} donor',
                    subtitle: 'Can give to ${[for (final e in bloodCompatibility.entries) if (e.value.contains(widget.bloodGroup)) e.key].join(', ')}',
                  ),
                  if (updatedAt != null)
                    RbRow(icon: RbGlyph.clock, tone: RbTone.neutral, title: _updatedLabel(updatedAt)),
                ],
              ),
              const RbSectionLabel('Privacy'),
              RbCard(
                color: AppColors.goldTint,
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RbIcon(RbGlyph.shield, size: 18, color: AppColors.goldDeep),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Phone numbers are never shown. Once a donor accepts your request you can message and call each other inside the app.',
                        style: TextStyle(fontSize: 13.5, color: AppColors.goldDeepest, height: 1.5),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _statTile(Widget value, String label) {
    return Expanded(
      child: Container(
        height: 92,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(color: Colors.white, border: Border.all(color: AppColors.warmBorder), borderRadius: BorderRadius.circular(AppTheme.controlRadius)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            value,
            const SizedBox(height: 4),
            Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, color: AppColors.ink2)),
          ],
        ),
      ),
    );
  }
}
