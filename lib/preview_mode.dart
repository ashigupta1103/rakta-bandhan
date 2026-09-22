import 'package:flutter/foundation.dart' show kReleaseMode;

/// Single source of truth for "are we allowed to show local sample content
/// instead of real backend data". On by default outside release builds
/// (`flutter run`/debug/profile), off in any real release build unless the
/// `ENABLE_PREVIEW_UI` dart-define explicitly turns it on for a client demo
/// build — so a normal production release never ships fictional people,
/// partnerships or statistics, and a demo build can turn it on deliberately.
const kEnablePreviewUi = bool.fromEnvironment('ENABLE_PREVIEW_UI', defaultValue: !kReleaseMode);
