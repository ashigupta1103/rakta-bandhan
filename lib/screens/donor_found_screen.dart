import 'package:flutter/material.dart';
import '../services/donor_match_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/contact_actions.dart';
import '../widgets/match_pair.dart';
import '../widgets/rb_icon.dart';
import 'donor_details_screen.dart';
import 'tracking_screen.dart';

/// "A donor accepted your request" — the requester's matched moment on the
/// ember field. The donor identity comes from FirestoreDonorMatchService,
/// reading the real match written by Backend.acceptRequest (see
/// donor_match_service.dart); in a client demo, from the demo persona.
class DonorFoundScreen extends StatelessWidget {
  final String requestId;

  const DonorFoundScreen({super.key, required this.requestId});

  Future<DonorMatch> _fetch() => FirestoreDonorMatchService().fetchMatch(requestId);

  void _goHome(BuildContext context) => Navigator.of(context).popUntil((route) => route.isFirst);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.gradientEmberStart,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment(-0.25, -1),
            end: Alignment(0.25, 1),
            colors: [AppColors.gradientEmberStart, AppColors.gradientEmberMid, AppColors.gradientEmberEnd],
            stops: [0, 0.68, 1],
          ),
        ),
        child: SafeArea(
          child: FutureBuilder<DonorMatch>(
            future: _fetch(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return _note(context, 'Couldn’t load your donor’s details. Your request is still matched — open it from the Requests tab.');
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.onEmberAccent));
              }
              final donor = snapshot.data!;
              final first = donor.name.split(' ').first;
              return ListView(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(tooltip: 'Home', icon: const RbIcon(RbGlyph.back, color: AppColors.onEmberStrong), onPressed: () => _goHome(context)),
                  ),
                  const SizedBox(height: 8),
                  Center(child: MatchPair(peerName: donor.name, bloodGroup: donor.bloodGroup)),
                  const SizedBox(height: 22),
                  const Text('Donor found', textAlign: TextAlign.center, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppColors.onEmberEyebrow)),
                  const SizedBox(height: 8),
                  Text('$first accepted\nyour request', textAlign: TextAlign.center, style: AppTextStyles.display(fontSize: 28, color: AppColors.onEmberStrong, height: 1.2)),
                  const SizedBox(height: 10),
                  Text(
                    [donor.bloodGroup, donor.distance, if (donor.isVerified) 'verified donor'].where((p) => p.isNotEmpty).join(' · '),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 14, color: AppColors.onEmberMuted, height: 1.5),
                  ),
                  const SizedBox(height: 6),
                  Center(
                    child: TextButton.icon(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => DonorDetailsScreen(
                            donorId: donor.uid,
                            name: donor.name,
                            initials: donor.initials,
                            bloodGroup: donor.bloodGroup,
                            isVerified: donor.isVerified,
                            distanceKm: null,
                            isAvailable: true,
                            matched: true,
                          ),
                        ),
                      ),
                      icon: const RbIcon(RbGlyph.person, size: 16, color: AppColors.onEmber),
                      label: Text('View $first’s profile', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.onEmber)),
                    ),
                  ),
                  const SizedBox(height: 18),
                  ContactActions(requestId: requestId, peerUid: donor.uid, peerName: donor.name),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(foregroundColor: AppColors.onEmber, side: const BorderSide(color: AppColors.onEmberOutline), minimumSize: const Size.fromHeight(46)),
                    onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => TrackingScreen(requestId: requestId))),
                    icon: const RbIcon(RbGlyph.route, size: 16),
                    label: const Text('Track request'),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Your phone number stays private. After the donation, you both confirm it in the app.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12.5, color: AppColors.onEmberFaint, height: 1.45),
                  ),
                  TextButton(
                    onPressed: () => _goHome(context),
                    child: const Text('Go home', style: TextStyle(fontSize: 13.5, color: AppColors.onEmberMuted)),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _note(BuildContext context, String text) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(text, textAlign: TextAlign.center, style: const TextStyle(fontSize: 14, color: AppColors.onEmberMuted, height: 1.5)),
              const SizedBox(height: 14),
              TextButton(onPressed: () => _goHome(context), child: const Text('Go home', style: TextStyle(color: AppColors.onEmber))),
            ],
          ),
        ),
      );
}
