import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../preview_mode.dart';
import '../services/backend.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/app_header.dart';
import '../widgets/blood_group_droplet.dart';
import '../widgets/brand_glyph.dart';
import '../widgets/rb_ui.dart';
import 'create_experience_screen.dart';
import 'notifications_screen.dart';

/// Community tab root. Stories are real: they live in `community_stories`
/// and are posted from CreateExperienceScreen. Likes/comments/leaderboard
/// rankings still need a public-handle model that does not exist yet, so
/// those stay as honest empty states rather than invented numbers. The
/// Impact tab reads the `public_stats/impact` counter (a normal user is not
/// permitted to query fulfilled requests — those carry phone numbers).
class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key});

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

enum _CommunityTab { stories, whatsNew, impact }

/// Names the kind of failure instead of always blaming the connection — a
/// permission error won't be fixed by retrying.
@visibleForTesting
String communityLoadErrorMessage(Object? error) {
  final code = error is FirebaseException ? error.code : null;
  return switch (code) {
    'permission-denied' || 'unauthenticated' => 'Your session may have expired. Sign out and back in, then try again.',
    'unavailable' || 'deadline-exceeded' => 'Check your connection and try again.',
    _ => 'Something went wrong on our side. Please try again.',
  };
}

class _CommunityScreenState extends State<CommunityScreen> {
  _CommunityTab _tab = _CommunityTab.stories;
  late Stream<int> _impactStream;
  // Not final: a Firestore snapshot stream is finished once it errors, so
  // "Try again" has to subscribe to a fresh one (a bare setState would just
  // rebuild against the same dead stream and show the error forever).
  Stream<QuerySnapshot<Map<String, dynamic>>> _stories = Backend.instance.communityStoriesStream();
  Stream<QuerySnapshot<Map<String, dynamic>>> _announcements = Backend.instance.announcementsStream();

  /// Authors this person chose to hide ("Hide posts from …") — kept on the
  /// device, so blocking someone never needs to tell them.
  Set<String> _hiddenAuthors = {};
  static const _hiddenAuthorsKey = 'rb_hidden_story_authors';

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((prefs) {
      if (mounted) setState(() => _hiddenAuthors = (prefs.getStringList(_hiddenAuthorsKey) ?? const []).toSet());
    }).catchError((_) {});
    // Reads the public_stats/impact counter, not a `requests` query: a
    // normal user is not allowed to query fulfilled requests (they carry
    // phone numbers), which is why the old query always errored out here.
    _impactStream = Backend.instance.impactThisMonthStream();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.warmPageBackground,
      appBar: AppHeader(
        title: 'Community',
        onNotificationTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const NotificationsScreen())),
      ),
      body: Column(
        children: [
          RbTabBar(
            tabs: const [('Stories', 0), ("What's new", 0), ('Impact', 0)],
            selected: _tab.index,
            onChanged: (i) => setState(() => _tab = _CommunityTab.values[i]),
          ),
          Expanded(
            child: switch (_tab) {
              _CommunityTab.stories => _storiesTab(),
              _CommunityTab.whatsNew => _whatsNewTab(),
              _CommunityTab.impact => _impactTab(),
            },
          ),
        ],
      ),
    );
  }

  void _openComposer() => Navigator.push(context, MaterialPageRoute(builder: (context) => const CreateExperienceScreen()));

  // ------------------------------------------------------------- Stories

  Widget _storiesTab() {
    return ListView(
      padding: kRbPagePadding,
      children: [
        _composer(),
        if (kEnablePreviewUi) ...[
          _previewLabel('Preview data — sample story layout'),
          _storyCard(
            'demo-1',
            const {'author_name': 'Demo Volunteer 01', 'topic': 'Volunteer appreciation', 'location_label': 'Sample area', 'body': 'Sample layout text — a short note thanking volunteers for a donation drive would appear here.'},
            demo: true,
          ),
          const SizedBox(height: 12),
        ],
        RbSectionLabel('Latest stories'),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _stories,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return RbStatePanel.error(
                title: "Couldn't load stories",
                message: communityLoadErrorMessage(snapshot.error),
                onRetry: () => setState(() => _stories = Backend.instance.communityStoriesStream()),
              );
            }
            if (!snapshot.hasData) return const _StorySkeleton();
            // Hidden stories are filtered here rather than in the query:
            // `where is_hidden == false` would need a composite index and
            // would also drop every story written before moderation
            // existed (no such field at all).
            final docs = snapshot.data!.docs
                .where((d) => d.data()['is_hidden'] != true && !_hiddenAuthors.contains(d.data()['author_uid']))
                .toList();
            if (docs.isEmpty) {
              return RbStatePanel(
                icon: LucideIcons.heartHandshake,
                tone: GlyphTone.gold,
                title: 'No stories yet',
                message: 'Be the first to share what donating — or receiving — meant to you.',
                actionLabel: 'Share your story',
                onAction: _openComposer,
              );
            }
            return Column(
              children: [
                for (final doc in docs) ...[
                  _storyCard(doc.id, doc.data()),
                  const SizedBox(height: 14),
                ],
              ],
            );
          },
        ),
      ],
    );
  }

  /// Looks like the start of a post, so it reads as "write here", not as
  /// another content card.
  Widget _composer() {
    return RbCard(
      onTap: _openComposer,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      child: Column(
        children: [
          Row(
            children: [
              const BrandGlyph(icon: LucideIcons.penLine, tone: GlyphTone.gold, size: 40),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                  decoration: BoxDecoration(color: AppColors.warmGround, borderRadius: BorderRadius.circular(999), border: Border.all(color: AppColors.warmBorder)),
                  child: const Text('Share your donation story…', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 14, color: AppColors.mutedInk)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Row(
            children: [
              SizedBox(width: 52),
              Icon(LucideIcons.image, size: 15, color: AppColors.ink2),
              SizedBox(width: 6),
              Text('Photo', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500, color: AppColors.ink2)),
              SizedBox(width: 16),
              Icon(LucideIcons.shieldCheck, size: 15, color: AppColors.ink2),
              SizedBox(width: 6),
              Expanded(child: Text('Guidelines apply', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500, color: AppColors.ink2))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _previewLabel(String text) => Padding(
        padding: const EdgeInsets.fromLTRB(2, 22, 2, 10),
        child: Row(
          children: [
            const Icon(LucideIcons.eye, size: 13, color: AppColors.goldDeep),
            const SizedBox(width: 6),
            Expanded(child: Text(text, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.goldDeep))),
          ],
        ),
      );

  /// A post: author row, the photo edge to edge (4:5 to 1.91:1, like
  /// Instagram's crop limits), then the text. Tap the photo for a
  /// full-screen, pinch-to-zoom view.
  Widget _storyCard(String id, Map<String, dynamic> data, {bool demo = false}) {
    final created = (data['created_at'] as Timestamp?)?.toDate();
    final bloodGroup = data['blood_group'] as String?;
    final location = data['location_label'] as String?;
    final topic = data['topic'] as String?;
    final imageUrl = data['image_url'] as String?;
    final aspect = ((data['image_aspect'] as num?)?.toDouble() ?? 4 / 5).clamp(4 / 5, 1.91);
    final isMine = !demo && data['author_uid'] == Backend.instance.currentUser?.uid;
    final name = data['author_name'] as String? ?? 'A donor';
    final meta = [
      if (location != null && location.isNotEmpty) location,
      if (created != null) _timeAgo(created) else if (demo) 'sample',
    ].join(' · ');

    return RbCard(
      padding: EdgeInsets.zero,
      clip: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 2, 10),
            child: Row(
              children: [
                SizedBox(
                  width: 42,
                  height: 42,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      RbAvatar(name: name, size: 40, gold: true),
                      if (bloodGroup != null)
                        Positioned(
                          right: -4,
                          bottom: -4,
                          child: Container(
                            padding: const EdgeInsets.all(1.5),
                            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                            child: BloodGroupDroplet(label: bloodGroup, size: 18, fontSize: 6.5),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: AppColors.ink)),
                      if (meta.isNotEmpty)
                        Text(meta, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: AppColors.ink2)),
                    ],
                  ),
                ),
                if (!demo)
                  PopupMenuButton<String>(
                    tooltip: 'More',
                    icon: const Icon(LucideIcons.ellipsis, size: 18, color: AppColors.ink2),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    onSelected: (action) => _onStoryAction(action, id, data),
                    itemBuilder: (_) => [
                      if (isMine) const PopupMenuItem(value: 'delete', child: Text('Delete post')),
                      if (!isMine) const PopupMenuItem(value: 'report', child: Text('Report post')),
                      if (!isMine) PopupMenuItem(value: 'hide', child: Text('Hide posts from ${name.split(' ').first}')),
                    ],
                  )
                else
                  const SizedBox(width: 12),
              ],
            ),
          ),
          if (imageUrl != null)
            GestureDetector(
              onTap: () => Navigator.push(context, MaterialPageRoute(fullscreenDialog: true, builder: (_) => _PhotoViewer(url: imageUrl))),
              child: AspectRatio(
                aspectRatio: aspect,
                child: Hero(
                  tag: imageUrl,
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    loadingBuilder: (context, child, progress) => progress == null ? child : Container(color: AppColors.sand),
                    errorBuilder: (_, _, _) => Container(
                      color: AppColors.sand,
                      alignment: Alignment.center,
                      child: const Icon(LucideIcons.imageOff, color: AppColors.ink2),
                    ),
                  ),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (topic != null && topic.isNotEmpty) ...[
                  RbChip(topic, tone: RbTone.gold),
                  const SizedBox(height: 10),
                ],
                Text(data['body'] as String? ?? '', style: const TextStyle(fontSize: 14.5, color: AppColors.ink, height: 1.55)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _onStoryAction(String action, String id, Map<String, dynamic> data) async {
    final messenger = ScaffoldMessenger.of(context);
    switch (action) {
      case 'delete':
        try {
          await Backend.instance.deleteMyStory(id);
          messenger.showSnackBar(const SnackBar(content: Text('Post deleted.')));
        } catch (_) {
          messenger.showSnackBar(const SnackBar(content: Text('Could not delete the post. Please try again.')));
        }
      case 'report':
        final reason = await showModalBottomSheet<String>(
          context: context,
          backgroundColor: Colors.white,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
          builder: (sheet) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 4),
                  child: Text('Why are you reporting this post?', style: AppTextStyles.display(fontSize: 19, color: AppColors.ink)),
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
                  child: Text('Our team reviews every report. The author isn’t told who reported it.', style: TextStyle(fontSize: 13, color: AppColors.ink2)),
                ),
                for (final r in const [
                  'Asking for or offering money for blood',
                  'Shares someone’s phone number or private details',
                  'Harassment or hateful content',
                  'Spam or advertising',
                  'Fake or misleading',
                  'Something else',
                ])
                  ListTile(title: Text(r, style: const TextStyle(fontSize: 14.5)), trailing: const Icon(LucideIcons.chevronRight, size: 16, color: AppColors.chevronMuted), onTap: () => Navigator.pop(sheet, r)),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
        if (reason == null) return;
        try {
          await Backend.instance.reportStory(id, reason: reason);
          messenger.showSnackBar(const SnackBar(content: Text('Thanks — our team will review this post.')));
        } catch (_) {
          messenger.showSnackBar(const SnackBar(content: Text('Could not send the report. Please try again.')));
        }
      case 'hide':
        final author = data['author_uid'] as String?;
        if (author == null) return;
        setState(() => _hiddenAuthors = {..._hiddenAuthors, author});
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setStringList(_hiddenAuthorsKey, _hiddenAuthors.toList());
        } catch (_) {}
        messenger.showSnackBar(const SnackBar(content: Text('You won’t see posts from this person.')));
    }
  }

  String _timeAgo(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 30) return '${diff.inDays}d ago';
    return '${(diff.inDays / 30).floor()}mo ago';
  }

  // ------------------------------------------------------------- What's new

  Widget _whatsNewTab() {
    return ListView(
      padding: kRbPagePadding,
      children: [
        Text('From the Rakta Bandhan team', style: AppTextStyles.display(fontSize: 20, color: AppColors.ink)),
        const SizedBox(height: 4),
        const Text('Camps, drives and updates from the trust. Only real, confirmed events are posted here.', style: TextStyle(fontSize: 13.5, color: AppColors.ink2, height: 1.45)),
        const SizedBox(height: 16),
        if (kEnablePreviewUi) ...[
          _announcementCard(const {'title': 'Demo community update', 'body': 'Sample layout text — a short update from Rakta Bandhan about ongoing work would appear here.'}, demo: true),
          const SizedBox(height: 12),
        ],
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _announcements,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return RbStatePanel.error(
                title: "Couldn't load announcements",
                message: communityLoadErrorMessage(snapshot.error),
                onRetry: () => setState(() => _announcements = Backend.instance.announcementsStream()),
              );
            }
            if (!snapshot.hasData) return const RbLoading();
            final docs = snapshot.data!.docs;
            if (docs.isEmpty) {
              return const RbStatePanel(
                icon: LucideIcons.megaphone,
                tone: GlyphTone.gold,
                title: 'No announcements yet',
                message: 'Blood camps, drives and initiatives will appear here once they are announced. No dates or venues are shown until they are real.',
              );
            }
            return Column(
              children: [
                for (final doc in docs) ...[
                  _announcementCard(doc.data()),
                  const SizedBox(height: 12),
                ],
              ],
            );
          },
        ),
      ],
    );
  }

  /// A real announcement written by an admin from the console's Content tab.
  Widget _announcementCard(Map<String, dynamic> data, {bool demo = false}) {
    final created = (data['created_at'] as Timestamp?)?.toDate();
    return RbCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const BrandGlyph(icon: LucideIcons.megaphone, tone: GlyphTone.gold, size: 38),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(data['title'] as String? ?? '', style: AppTextStyles.display(fontSize: 17, color: AppColors.ink, height: 1.25)),
                const SizedBox(height: 2),
                Text(
                  demo ? 'Preview sample' : (created != null ? _timeAgo(created) : 'Rakta Bandhan'),
                  style: const TextStyle(fontSize: 12, color: AppColors.mutedInk),
                ),
                const SizedBox(height: 8),
                Text(data['body'] as String? ?? '', style: const TextStyle(fontSize: 14, color: AppColors.ink2, height: 1.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------- Impact

  Widget _impactTab() {
    final month = const ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'][DateTime.now().month - 1];
    return ListView(
      padding: kRbPagePadding,
      children: [
        StreamBuilder<int>(
          stream: _impactStream,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return RbStatePanel.error(
                title: "Couldn't load this month's impact",
                message: communityLoadErrorMessage(snapshot.error),
                onRetry: () => setState(() => _impactStream = Backend.instance.impactThisMonthStream()),
              );
            }
            if (!snapshot.hasData) return const RbLoading();
            final count = snapshot.data!;
            return RbCard(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const BloodGroupDroplet(label: '', size: 16),
                      const SizedBox(width: 8),
                      Text('$month so far', style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppColors.ink2)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('$count', style: AppTextStyles.display(fontSize: 52, color: count == 0 ? AppColors.ink2 : AppColors.brandRed, height: 0.95)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Text(
                            count == 1 ? 'donation completed through the app' : 'donations completed through the app',
                            style: const TextStyle(fontSize: 14, color: AppColors.ink, height: 1.3),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Divider(height: 1, color: AppColors.warmDivider),
                  const SizedBox(height: 12),
                  Text(
                    count == 0
                        ? 'Nothing recorded yet this month. The figure updates the moment a donation is confirmed by both sides.'
                        : 'Counted only when both the donor and the requester confirm the donation.',
                    style: const TextStyle(fontSize: 13, color: AppColors.ink2, height: 1.45),
                  ),
                ],
              ),
            );
          },
        ),
        const RbSectionLabel('Recognition'),
        RbCard(
          color: AppColors.goldTint,
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(LucideIcons.award, size: 18, color: AppColors.goldDeep),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Donor recognition is coming. Rankings need a public community identity, which hasn’t launched yet — so there are no placeholder scores here.',
                  style: TextStyle(fontSize: 13.5, color: AppColors.goldDeepest, height: 1.5),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Two placeholder post shapes while stories load — keeps the layout from
/// jumping when the first real card arrives.
class _StorySkeleton extends StatelessWidget {
  const _StorySkeleton();

  @override
  Widget build(BuildContext context) {
    Widget bar(double w, {double h = 10}) => Container(width: w, height: h, decoration: BoxDecoration(color: AppColors.sand, borderRadius: BorderRadius.circular(6)));
    return Column(
      children: [
        for (var i = 0; i < 2; i++) ...[
          RbCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(width: 40, height: 40, decoration: const BoxDecoration(color: AppColors.sand, shape: BoxShape.circle)),
                    const SizedBox(width: 12),
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [bar(120), const SizedBox(height: 6), bar(80, h: 8)]),
                  ],
                ),
                const SizedBox(height: 16),
                bar(double.infinity),
                const SizedBox(height: 8),
                bar(200),
              ],
            ),
          ),
          const SizedBox(height: 14),
        ],
      ],
    );
  }
}

/// Full-screen, pinch-to-zoom photo from a community post.
class _PhotoViewer extends StatelessWidget {
  final String url;
  const _PhotoViewer({required this.url});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(icon: const Icon(LucideIcons.x), onPressed: () => Navigator.pop(context)),
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 1,
          maxScale: 4,
          child: Hero(tag: url, child: Image.network(url, fit: BoxFit.contain)),
        ),
      ),
    );
  }
}
