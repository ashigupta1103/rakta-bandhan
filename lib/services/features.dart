// Which outside services are connected. Everything not listed here is real
// and works on the free Firebase (Spark) plan: Firestore data, chat, calls,
// photos (Cloudflare R2) and the TURN relay.

/// Emailed 6-digit sign-in code. It needs the Cloud Functions (Blaze plan)
/// and an email sender, so until both exist sign-in is email + password
/// with the verification email Firebase sends itself (free). After the
/// upgrade, build with `--dart-define=EMAIL_CODE_LIVE=true`.
const kEmailCodeLive = bool.fromEnvironment('EMAIL_CODE_LIVE');

/// The phone-number check has no SMS / WhatsApp / Truecaller provider behind
/// it yet, so its screen is a labelled simulation: it sends nothing and
/// verifies nothing. Replace the screen's internals when a provider exists.
const kSimulatedPhoneCode = '246810';
