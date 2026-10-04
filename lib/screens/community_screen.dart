
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/backend.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/app_header.dart';
import '../widgets/blood_group_droplet.dart';
import '../widgets/brand_glyph.dart';
import '../widgets/rb_ui.dart';
import 'create_experience_screen.dart';
import 'notifications_screen.dart';
import 'testimonials_screen.dart';
import '../widgets/rb_icon.dart';

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
  Stream<List<_Doc>> _stories = _storiesStream();
  Stream<List<_Doc>> _announcements = _announcementsStream();

  static List<_Doc> _docs(QuerySnapshot<Map<String, dynamic>> q) => [for (final d in q.docs) (id: d.id, data: d.data())];

  static Stream<List<_Doc>> _storiesStream() => Backend.instance.communityStoriesStream().map(_docs);

  static Stream<List<_Doc>> _announcementsStream() => Backend.instance.announcementsStream().map(_docs);

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
    _impactStream = _impact();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.warmPageBackground,
      appBar: AppHeader(
        title: 'Community',
        showDivider: false, // the tab bar below draws the one hairline
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

  static Stream<int> _impact() => Backend.instance.impactThisMonthStream();

  void _openComposer() => Navigator.push(context, MaterialPageRoute(builder: (context) => const CreateExperienceScreen()));

  // ------------------------------------------------------------- Stories

  Widget _storiesTab() {
    return ListView(
      padding: kRbPagePadding,
      children: [
        _composer(),
        const SizedBox(height: 8),
        RbEntryRow(
          icon: RbGlyph.quote,
          title: 'Testimonials',
          subtitle: 'Read them, or add yours after a donation',
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TestimonialsScreen())),
        ),
        const RbSectionLabel('Latest stories', padding: EdgeInsets.fromLTRB(2, 18, 2, 8)),
        StreamBuilder<List<_Doc>>(
          stream: _stories,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return RbStatePanel.error(
                title: "Couldn't load stories",
                message: communityLoadErrorMessage(snapshot.error),
                onRetry: () => setState(() => _stories = _storiesStream()),
              );
            }
            if (!snapshot.hasData) return const _StorySkeleton();
            // Hidden stories are filtered here rather than in the query:
            // `where is_hidden == false` would need a composite index and
            // would also drop every story written before moderation
            // existed (no such field at all).
            final docs = snapshot.data!.where((d) => d.data['is_hidden'] != true && !_hiddenAuthors.contains(d.data['author_uid'])).toList();
            if (docs.isEmpty) {
              return RbStatePanel(
                icon: RbGlyph.community,
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
                  _storyCard(doc.id, doc.data),
                  const SizedBox(height: 14),
                ],
              ],
            );
          },
        ),
      ],
    );
  }

  /// Looks like the start of a post: one slim row, not a card of its own.
  Widget _composer() => RbEntryRow(
        icon: RbGlyph.pen,
        title: 'Share your donation story…',
        trailing: const RbIcon(RbGlyph.photo, size: 18, color: AppColors.ink2),
        onTap: _openComposer,
      );

  /// A post: author row, the photo edge to edge (4:5 to 1.91:1, like
  /// Instagram's crop limits), then the text. Tap the photo for a
  /// full-screen, pinch-to-zoom view.
  Widget _storyCard(String id, Map<String, dynamic> data) {
    final created = (data['created_at'] as Timestamp?)?.toDate();
    final bloodGroup = data['blood_group'] as String?;
    final location = data['location_label'] as String?;
    final topic = data['topic'] as String?;
    final imageUrl = data['image_url'] as String?;
    final aspect = ((data['image_aspect'] as num?)?.toDouble() ?? 4 / 5).clamp(4 / 5, 1.91);
    final isMine = data['author_uid'] == Backend.instance.currentUser?.uid;
    // Own stories only (author_uid matches the signed-in user).
    final canEdit = isMine;
    // Public identity is the username only — never the registered name.
    final username = (data['author_username'] as String?)?.trim();
    final hasUsername = username != null && username.isNotEmpty;
    final name = hasUsername ? '@$username' : 'A donor';
    final meta = [
      if (location != null && location.isNotEmpty) location,
      if (created != null) _timeAgo(created),
      if (data['edited_at'] != null) 'edited',
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
                      RbAvatar(name: hasUsername ? username : 'Donor', size: 40, gold: true),
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
                PopupMenuButton<String>(
                  tooltip: isMine ? 'Story options' : 'More',
                  icon: const RbIcon(RbGlyph.more, size: 18, color: AppColors.ink2),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  color: Colors.white,
                  onSelected: (action) => _onStoryAction(action, id, data),
                  itemBuilder: (_) => [
                    if (canEdit) _menuItem('edit', RbGlyph.pen, 'Edit story'),
                    if (isMine) _menuItem('delete', RbGlyph.trash, 'Delete story', destructive: true),
                    if (!isMine) const PopupMenuItem(value: 'report', child: Text('Report post')),
                    if (!isMine) PopupMenuItem(value: 'hide', child: Text('Hide posts from $name')),
                  ],
                ),
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
                      child: const RbIcon(RbGlyph.photoOff, color: AppColors.ink2),
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

  PopupMenuItem<String> _menuItem(String value, RbGlyph glyph, String label, {bool destructive = false}) => PopupMenuItem(
        value: value,
        child: Row(
          children: [
            RbIcon(glyph, size: 17, color: destructive ? AppColors.red700 : AppColors.ink2, accent: Colors.transparent),
            const SizedBox(width: 10),
            Text(label, style: TextStyle(fontSize: 14.5, color: destructive ? AppColors.red700 : AppColors.ink)),
          ],
        ),
      );

  Future<bool> _confirmDeleteStory() async =>
      await showDialog<bool>(
        context: context,
        builder: (dialog) => AlertDialog(
          backgroundColor: AppColors.warmGround,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('Delete this story?', style: AppTextStyles.display(fontSize: 20, color: AppColors.ink)),
          content: const Text('This action can’t be undone.', style: TextStyle(fontSize: 14, color: AppColors.ink2, height: 1.45)),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialog, false), child: const Text('Cancel', style: TextStyle(color: AppColors.ink2))),
            TextButton(
              onPressed: () => Navigator.pop(dialog, true),
              style: TextButton.styleFrom(foregroundColor: AppColors.red700),
              child: const Text('Delete', style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ) ??
      false;

  Future<void> _onStoryAction(String action, String id, Map<String, dynamic> data) async {
    final messenger = ScaffoldMessenger.of(context);
    switch (action) {
      case 'edit':
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CreateExperienceScreen(
              editStoryId: id,
              initialBody: data['body'] as String? ?? '',
              initialTopic: data['topic'] as String?,
            ),
          ),
        );
      case 'delete':
        if (!await _confirmDeleteStory() || !mounted) return;
        try {
          await Backend.instance.deleteMyStory(id);
          messenger.showSnackBar(const SnackBar(content: Text('Story deleted.')));
        } catch (_) {
          messenger.showSnackBar(const SnackBar(content: Text('Could not delete the story. Please try again.')));
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
                  ListTile(title: Text(r, style: const TextStyle(fontSize: 14.5)), trailing: const RbIcon(RbGlyph.chevron, size: 16, color: AppColors.chevronMuted), onTap: () => Navigator.pop(sheet, r)),
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
        StreamBuilder<List<_Doc>>(
          stream: _announcements,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return RbStatePanel.error(
                title: "Couldn't load announcements",
                message: communityLoadErrorMessage(snapshot.error),
                onRetry: () => setState(() => _announcements = _announcementsStream()),
              );
            }
            if (!snapshot.hasData) return const RbLoading();
            final docs = snapshot.data!;
            if (docs.isEmpty) {
              return const RbStatePanel(
                icon: RbGlyph.megaphone,
                tone: GlyphTone.gold,
                title: 'No announcements yet',
                message: 'Blood camps, drives and initiatives will appear here once they are announced. No dates or venues are shown until they are real.',
              );
            }
            return Column(
              children: [
                for (final doc in docs) ...[
                  _announcementCard(doc.data),
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
  Widget _announcementCard(Map<String, dynamic> data) {
    final created = (data['created_at'] as Timestamp?)?.toDate();
    return RbCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const BrandGlyph(icon: RbGlyph.megaphone, tone: GlyphTone.gold, size: 38),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(data['title'] as String? ?? '', style: AppTextStyles.display(fontSize: 17, color: AppColors.ink, height: 1.25)),
                const SizedBox(height: 2),
                Text(
                  created != null ? _timeAgo(created) : 'Rakta Bandhan',
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
                onRetry: () => setState(() => _impactStream = _impact()),
              );
            }
            if (!snapshot.hasData) return const RbLoading();
            final count = snapshot.data!;
            if (count == 0) {
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
                decoration: BoxDecoration(color: Colors.white, border: Border.all(color: AppColors.red100, width: 1.5), borderRadius: BorderRadius.circular(20)),
                child: Column(
                  children: [
                    const BrandGlyph(icon: RbGlyph.droplet, size: 52),
                    const SizedBox(height: 16),
                    Text('No donations recorded this month yet', textAlign: TextAlign.center, style: AppTextStyles.display(fontSize: 18, color: AppColors.ink)),
                    const SizedBox(height: 8),
                    const Text(
                      'This counts donations confirmed by both the donor and the requester. It updates the moment the first one this month is recorded.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: AppColors.ink2, height: 1.5),
                    ),
                  ],
                ),
              );
            }
            return Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment(-0.3, -1),
                  end: Alignment(0.3, 1),
                  colors: [AppColors.emberFieldStart, AppColors.emberFieldMid, AppColors.emberFieldEnd],
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Together this month', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppColors.gold)),
                  const SizedBox(height: 10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('$count', style: AppTextStyles.display(fontSize: 46, color: AppColors.onEmberWarm, height: 0.9)),
                      const SizedBox(width: 12),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 7),
                        child: Text(count == 1 ? 'donation by\nthe community' : 'donations by\nthe community', style: const TextStyle(fontSize: 14, height: 1.25, color: AppColors.onEmberWarm)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Counted when both the donor and the requester confirm a donation.',
                    style: const TextStyle(fontSize: 12, color: AppColors.onEmberMuted),
                  ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 22),
        const Text('Community impact', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.ink2)),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: const BoxDecoration(
            color: AppColors.goldTint,
            border: Border(left: BorderSide(color: AppColors.gold, width: 3)),
            borderRadius: BorderRadius.horizontal(right: Radius.circular(12)),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RbIcon(RbGlyph.certificate, size: 16, color: AppColors.goldDeep),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Recognition is coming. Individual rankings and Donor of the Year need a public community identity, which hasn’t launched yet — nothing here is a placeholder score.',
                  style: TextStyle(fontSize: 12.5, color: AppColors.goldDeepest, height: 1.5),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// A document id and its fields from Firestore.
typedef _Doc = ({String id, Map<String, dynamic> data});

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
        leading: IconButton(
                      tooltip: 'Close',icon: const RbIcon(RbGlyph.close), onPressed: () => Navigator.pop(context)),
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
