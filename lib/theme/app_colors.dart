import 'package:flutter/material.dart';

/// Rakta Bandhan design tokens — the logo-derived warm system from the
/// approved final artifact (`design_updated/Rakta Bandhan Redesign.dc.html`,
/// section "01 · The design system"). Three brand hues (red/orange/gold)
/// sampled from the supplied logo, each on a light-to-dark ramp, over warm
/// paper neutrals. Every screen should read colour from here — never a
/// hard-coded hex per screen.
class AppColors {
  AppColors._();

  // ── Brand ramps (named per the source artifact) ──────────────────────
  // Red — action, urgency, the blood itself.
  static const Color red100 = Color(0xFFFCEBE6);
  static const Color red200 = Color(0xFFF5D8D1);
  static const Color red300 = Color(0xFFE8A79C);
  static const Color brandRed = Color(0xFFB81E14); // 600 base
  static const Color red700 = Color(0xFFA81C13);
  static const Color red800 = Color(0xFF8E170F);
  static const Color red900 = Color(0xFF6E1109); // "Ember" swatch
  static const Color ember = red900;

  // Vermilion / orange — warmth, progress, the bridge.
  static const Color orangeTint = Color(0xFFFDECDC);
  static const Color orangeTint2 = Color(0xFFFADCC0);
  static const Color vermilion = Color(0xFFC9481E);
  static const Color orange = Color(0xFFD9631F);
  static const Color orangeDeep = Color(0xFFA34115);

  // Gold — community, recognition, Rotary.
  static const Color goldTint = Color(0xFFFBF0D9);
  static const Color goldTint2 = Color(0xFFF7E4BD);
  static const Color gold = Color(0xFFE0A030); // 500 brand
  static const Color goldDeep = Color(0xFF8A5D12);
  static const Color goldDeepest = Color(0xFF63410B);

  // Warm neutrals — paper, ink, edges.
  static const Color warmGround = Color(0xFFFCF8F2);
  static const Color sand = Color(0xFFF5EDE1);
  static const Color warmBorder = Color(0xFFEADFCF);
  static const Color warmDivider = Color(0xFFF2E9DC);
  static const Color disabledTint = Color(0xFFC2B2A9);
  static const Color mutedInk = Color(0xFFA2908A);
  static const Color ink2 = Color(0xFF6B534E);
  static const Color ink = Color(0xFF241413);

  // Semantic status.
  static const Color successBg = Color(0xFFE8F0DF);
  static const Color successText = Color(0xFF3F6B34);
  static const Color warningBg = goldTint;
  static const Color warningText = Color(0xFF9A6510);
  static const Color errorBg = red100;
  static const Color errorText = red700;

  // Ember field (168°) — consent, search, match, certificate only.
  static const Color emberFieldStart = red800;
  static const Color emberFieldMid = Color(0xFF4A0D08);
  static const Color emberFieldEnd = Color(0xFF1E0705);

  // ── Legacy semantic names — repointed to the new system so every screen
  // still using these constants picks up the new palette automatically,
  // without a screen-by-screen rewrite. New code should prefer the named
  // tokens above; these remain for the existing widget/screen surface.
  static const Color primary = brandRed;
  static const Color primaryLightTint = red100;
  static const Color primaryTextOnWhite = brandRed;
  static const Color primaryOnTintText = red700;
  static const Color whiteTextOnPrimary = Color(0xFFFFF3F0);

  static const Color textPrimary = ink;
  static const Color textSecondary = ink2;
  static const Color textMuted = mutedInk;
  static const Color border = warmBorder;
  static const Color borderStrong = disabledTint;
  static const Color surface = Color(0xFFFFFFFF);
  static const Color pageBackground = warmGround;
  static const Color mapBase = Color(0xFFEFE7DA);
  static const Color mapGridRoads = Color(0xFFDCCFB8);
  static const Color statBlockBackground = sand;
  static const Color tabTrackBackground = Color.fromARGB(15, 36, 20, 19);

  // Status colours (Requests/Availability) — mapped onto the new
  // urgent/pending/available pill vocabulary from the artifact.
  static const Color statusUrgentBg = orangeTint;
  static const Color statusUrgentText = orangeDeep;

  static const Color statusPendingBg = goldTint;
  static const Color statusPendingText = goldDeep;

  static const Color statusAvailableBg = successBg;
  static const Color statusAvailableText = successText;

  static const Color statusCompletedBg = successBg;
  static const Color statusCompletedText = successText;

  // Gradient surfaces — the ember field, used for the emotional-peak
  // moments (consent, search, match, certificate) only.
  static const Color gradientHeroStart = emberFieldStart;
  static const Color gradientHeroEnd = emberFieldEnd;
  static const Color gradientHeaderStart = emberFieldStart;
  static const Color gradientHeaderEnd = emberFieldEnd;
  static const Color gradientAvatarStart = brandRed;
  static const Color gradientAvatarEnd = red800;
  static const Color gradientMatchingStart = emberFieldStart;
  static const Color gradientMatchingEnd = emberFieldEnd;
  static const Color gradientMarkerStart = Color(0xFFD2503C);
  static const Color gradientMarkerEnd = brandRed;

  // Soft coloured shadows under gradient/primary surfaces.
  static const Color shadowButton = Color.fromRGBO(184, 30, 20, 0.24);
  static const Color shadowCard = Color.fromRGBO(110, 17, 9, 0.06);
  static const Color shadowHero = Color.fromRGBO(110, 17, 9, 0.28);
  static const Color shadowDark = Color.fromRGBO(30, 7, 5, 0.24);

  // Warm editorial surfaces (Home/Profile/Notifications/Settings) — now
  // the same warm system as everything else; kept as named aliases since
  // a large share of the app already reads these specific names.
  static const Color textPrimaryWarm = ink;
  static const Color warmPageBackground = warmGround;
  static const Color cardBorderWarm = warmBorder;
  static const Color dividerWarm = warmDivider;
  static const Color textMutedWarm = mutedInk;
  static const Color chevronMuted = disabledTint;

  static const Color warmAmberBg = goldTint;
  static const Color warmAmberBorder = goldTint2;
  static const Color warmAmberText = goldDeep;
  static const Color warmAmberIconTint = goldTint2;

  static const Color warmGreenBg = successBg;
  static const Color warmGreenBorder = successBg;
  static const Color warmGreenText = successText;

  // Ember gradient — the dark red-to-black field used for the emotional
  // peak moments (Onboarding page 1 "Brand", and Matched/donor-found).
  static const Color gradientEmberStart = emberFieldStart;
  static const Color gradientEmberMid = emberFieldMid;
  static const Color gradientEmberEnd = emberFieldEnd;
}
