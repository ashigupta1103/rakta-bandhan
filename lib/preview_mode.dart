import 'package:flutter/foundation.dart' show kReleaseMode;

/// Demo APK for the free (Spark) plan, where no server can email a sign-in
/// code: sign-in and the phone check are simulated on the device (see
/// lib/demo/demo.dart; the codes are `Demo.emailCode` and `Demo.phoneOtp`).
/// Build with `--dart-define=DEMO_SIGNIN=true`; leave it off once the backend
/// is live. Implies [kEnablePreviewUi].
const kDemoSignIn = bool.fromEnvironment('DEMO_SIGNIN');

/// Single source of truth for "are we allowed to show local sample content
/// instead of real backend data". On by default outside release builds
/// (`flutter run`/debug/profile), off in any real release build unless the
/// `ENABLE_PREVIEW_UI` dart-define explicitly turns it on for a client demo
/// build — so a normal production release never ships fictional people,
/// partnerships or statistics, and a demo build can turn it on deliberately.
const kEnablePreviewUi = kDemoSignIn || bool.fromEnvironment('ENABLE_PREVIEW_UI', defaultValue: !kReleaseMode);
