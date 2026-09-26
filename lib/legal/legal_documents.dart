import 'package:flutter/foundation.dart';

import 'legal_config.dart';

/// Body lines: a plain string is a paragraph; a string starting with "- "
/// is a bullet.
@immutable
class LegalSection {
  final String id;
  final String heading;
  final List<String> body;
  const LegalSection(this.id, this.heading, this.body);
}

@immutable
class LegalDocument {
  final String title;
  final String intro;
  /// "In short" — the plain-language summary shown above the full text.
  final List<String> summary;
  final List<LegalSection> sections;
  const LegalDocument({required this.title, required this.intro, required this.summary, required this.sections});
}

// DRAFT — written to match what the app actually does today (see
// lib/services/*.dart and backend/firestore.rules). Not legal advice; must
// be reviewed by counsel before kLegalApproved is set. If app behaviour
// changes (e.g. real OTP, push notifications on the Blaze plan), update the
// matching section here in the same change.

const privacyPolicy = LegalDocument(
  title: 'Privacy policy',
  intro:
      'Rakta Bandhan connects people who urgently need blood with willing donors nearby. To do that we handle two sensitive things — your phone number and where you are — plus your blood group. This policy explains what we collect, who can see it, and how to get it back or deleted.',
  summary: [
    'Your phone number is never shown in donor lists or on the map. It is shared with one person only: the person you are matched with on a request.',
    'Other users see your approximate area (about 1 km), never your address.',
    'Chat and calls happen inside the app. Calls are not recorded.',
    'We don’t sell your data or show ads.',
    'You can download your data or delete your account from Settings at any time.',
  ],
  sections: [
    LegalSection('who', 'Who we are', [
      'Rakta Bandhan is a not-for-profit initiative of the $kLegalEntity, $kLegalCity, India. For the purposes of the Digital Personal Data Protection Act, 2023 (DPDP Act), we are the Data Fiduciary for the personal data described here.',
    ]),
    LegalSection('collect', 'What we collect', [
      'Account and profile — what you give us:',
      '- Your name and mobile number.',
      '- Your blood group.',
      '- The area you register from: a location label you choose and its map coordinates.',
      '- Whether you are available to donate, and the date of your last donation recorded in the app.',
      '- Optionally, a photo of an ID document, if you submit one for verification.',
      'Requests — when you ask for blood: the blood group and number of units needed, how urgent it is, the location (usually a hospital) and its coordinates, and the request’s status over time.',
      'Conversations — when you are matched: the messages you send in the in-app chat, any location you choose to share in it (the hospital, or your position at that moment — never tracked continuously), when you last read the conversation (shown to the other person as “Seen”), and a record of in-app calls (who called whom, when, how long, and whether it was answered). The audio of calls is never recorded or stored.',
      'Safety reports — if you report someone: the reason you chose and any details you add.',
      'App usage — through Google Firebase Analytics: a small set of events (such as registering, creating a request, being matched, completing a donation), plus information Firebase collects automatically such as an app-instance identifier, device model, operating system, and approximate region derived from your IP address.',
      'Notification settings — whether you turned on urgent alerts and, if you allowed notifications, a push-notification token for your device.',
    ]),
    LegalSection('use', 'How we use it', [
      '- To match requests with compatible donors nearby — using blood group, approximate location and availability.',
      '- To let a matched requester and donor reach each other, through in-app chat and calls or by phone.',
      '- To verify donors, when an administrator reviews a submitted ID.',
      '- To enforce the donation cooldown (90 days after a donation recorded in the app) and to expire requests that go unanswered for 6 hours.',
      '- To keep people safe: reviewing reports, and suspending accounts that misuse the service.',
      '- To understand, in aggregate, whether the service is working (for example how many requests get matched).',
      'We do not use your data for advertising, and we do not sell or rent it to anyone.',
    ]),
    LegalSection('visible', 'What other people can see', [
      'Any signed-in user can see, for donors who are available: first and last name as registered, blood group, verification status, and an approximate location rounded to about 1 km. This is how requesters find donors on the map.',
      'Any signed-in user can see open requests: the blood group and units needed, urgency, and the request’s location.',
      'Only after a match — when a donor accepts a request — the two people involved can see each other’s name and phone number, message each other in the app, and call each other in the app. Nobody else can see that conversation. Tapping a shared location opens it in your maps app (for example Google Maps), which then handles it under its own privacy terms.',
      'Because in-app call audio travels directly between the two phones, each phone learns the other’s network (IP) address for the duration of the call. This is how internet calling works; it does not reveal your phone number.',
    ]),
    LegalSection('admins', 'What our administrators can see', [
      'A small team of Rakta Bandhan administrators can see donor profiles including phone numbers, submitted ID photos, requests, and safety reports. They can read the chat on a request to review a report of abuse. Administrators cannot listen to calls — there is no recording to listen to. Every verification, ban and administrative change is written to an audit log.',
    ]),
    LegalSection('processors', 'Services we rely on', [
      '- Google Firebase (Google LLC) — sign-in, the database that stores everything above, analytics and, where enabled, push notifications. Data is stored on Google Cloud servers, which may be located outside India.',
      '- OpenStreetMap — when you search for an address, the text you type is sent to the OpenStreetMap Foundation’s Nominatim service. When you use your current location to fill in an address, your coordinates are sent to that service to look up the street name. Map images are loaded from OpenStreetMap’s tile servers, which see your IP address and the area of the map you are viewing.',
      '- Google’s public STUN servers — used for a moment at the start of each in-app call to help the two phones find each other. They see your IP address, not the call.',
      'These providers process data under their own privacy terms. We do not give your data to anyone else, except where the law requires it — for example a valid order from a court or government authority.',
    ]),
    LegalSection('retention', 'How long we keep it', [
      '- Your profile is kept for as long as your account exists.',
      '- Requests, chat messages and call records are kept as part of the request’s history so both people have a record of what happened.',
      '- When you delete your account, we delete your profile, your public listing, any ID photo, and every chat message you sent. Requests you raised are cancelled if still open, and your name and phone number are removed from them. If you were matched as a donor on an open request, that request is released back to other donors. A record that a donation happened is kept without anything that identifies you.',
      '- Analytics data is kept according to Firebase Analytics retention settings, up to 14 months.',
    ]),
    LegalSection('rights', 'Your rights', [
      'Under the DPDP Act you have the right to:',
      '- Access your data — Settings › Download my data gives you a copy of everything stored against your account.',
      '- Correct it — contact us and we will fix anything that is wrong.',
      '- Erase it — Settings › Delete my account removes your account immediately, as described above.',
      '- Withdraw consent — turn off availability or urgent alerts at any time, or delete your account. Withdrawing consent doesn’t affect anything done before you withdrew it.',
      '- Grievance redressal — raise a complaint with our Grievance Officer (below), and if you are not satisfied, with the Data Protection Board of India.',
      '- Nominate someone to exercise these rights on your behalf in the event of death or incapacity.',
    ]),
    LegalSection('security', 'How we protect it', [
      'Data is encrypted in transit and at rest by Google Cloud. Access is enforced by database security rules: your phone number and ID photo sit in a private record only you and administrators can read, and the public donor listing never contains a phone number. In-app calls are encrypted end to end between the two phones (WebRTC DTLS-SRTP). No system is perfectly secure; if a breach affects you, we will tell you and the Data Protection Board as the law requires.',
    ]),
    LegalSection('children', 'Age limit', [
      'Rakta Bandhan is for people aged 18 and over — the minimum age to donate blood in India. We do not knowingly collect data from anyone under 18. If you believe a child has registered, contact us and we will delete the account.',
    ]),
    LegalSection('changes', 'Changes to this policy', [
      'If we change how we handle your data, we will update this page and its effective date, and tell you in the app before the change takes effect when it matters to you.',
    ]),
  ],
);

const termsOfUse = LegalDocument(
  title: 'Terms of use',
  intro:
      'These terms are the agreement between you and Rakta Bandhan, an initiative of the $kLegalEntity. By creating an account you accept them. Please read the section on what Rakta Bandhan is not — it matters in an emergency.',
  summary: [
    'Rakta Bandhan helps people find each other. It is not a blood bank, hospital or medical service.',
    'Donations happen only at licensed blood centres and hospitals, whose medical staff decide who can donate.',
    'Blood must never be bought or sold. Anyone who asks for or offers money is removed.',
    'In a medical emergency, call 108 or 112 first.',
  ],
  sections: [
    LegalSection('eligibility', 'Who can use Rakta Bandhan', [
      '- You must be at least 18 years old.',
      '- You must give accurate information — especially your name, phone number and blood group — and keep your availability honest.',
      '- One account per person. Your account is personal; don’t let anyone else use it.',
    ]),
    LegalSection('not', 'What Rakta Bandhan is — and is not', [
      'Rakta Bandhan is a platform that lets someone who needs blood reach willing, compatible donors nearby, and lets them contact each other.',
      'It is not a blood bank, hospital, laboratory or medical provider. We do not collect, test, store, process or transfuse blood, and we give no medical advice.',
      '- Blood compatibility shown in the app is a guide for matching only. Testing and cross-matching are always done by the blood centre.',
      '- Whether a person may donate is decided by the medical staff at the blood centre on the day, not by the app. A “verified” badge means an administrator checked an ID — it is not a medical clearance.',
      '- We cannot guarantee that a donor will be found, will accept, or will arrive, or how quickly.',
      'In a medical emergency, contact the hospital, call 108 (ambulance) or 112, and approach licensed blood banks directly. Use Rakta Bandhan alongside those channels, never instead of them.',
    ]),
    LegalSection('money', 'No payment for blood', [
      'Blood donation in India is voluntary and unpaid. Selling or buying blood, or offering or asking for money or gifts in exchange for a donation, is prohibited on Rakta Bandhan and may be against the law.',
      'Normal hospital processing charges set by a licensed blood centre are a matter between the patient and that centre and have nothing to do with the donor.',
      'If anyone asks you for money or offers you money, report them from the chat menu. We remove such accounts.',
    ]),
    LegalSection('donors', 'If you donate', [
      '- Only accept a request you genuinely intend and are able to fulfil. If plans change, use “Can’t make it” so the request goes straight back to other donors.',
      '- Follow the donation interval your blood centre advises. In India this is typically at least 3 months between whole-blood donations for men and 4 months for women. The app pauses your availability for 90 days after a donation you record.',
      '- Answer the blood centre’s health questions honestly — it protects the patient and you.',
    ]),
    LegalSection('requesters', 'If you request blood', [
      '- Only raise genuine requests, with the correct blood group, units and hospital.',
      '- Cancel the request as soon as the need is met, so donors aren’t called out for nothing.',
      '- Use the donor’s contact details only to arrange this donation.',
    ]),
    LegalSection('conduct', 'Chats, calls and conduct', [
      'In-app chat and calls exist for one purpose: arranging a donation. You agree not to:',
      '- harass, threaten, abuse or discriminate against anyone;',
      '- share someone else’s contact details or personal information without their consent, or use them for anything other than the donation;',
      '- post false, misleading or spam content, or impersonate anyone;',
      '- try to access accounts, data or parts of the service that aren’t yours, or interfere with how it works.',
      'You can report and block anyone from the chat menu. Blocking closes the conversation for both people.',
    ]),
    LegalSection('alerts', 'Urgent alerts', [
      'If you turn on urgent alerts, your phone may play a sound and show a full-screen alert when an urgent, compatible request is raised near you. They are best effort — an alert may be delayed or not arrive, for example if the app is closed, your phone is offline, or notifications are blocked. You can turn them off at any time.',
    ]),
    LegalSection('suspension', 'Suspension and removal', [
      'We may verify, restrict, suspend or remove an account that breaks these terms, puts anyone at risk, or misuses the service — usually after reviewing a report. You can stop using Rakta Bandhan and delete your account at any time from Settings.',
    ]),
    LegalSection('liability', 'Disclaimers and liability', [
      'Rakta Bandhan is provided free of charge by volunteers, “as is” and “as available”. To the extent the law allows, we are not liable for the acts or omissions of any user, for whether a donation takes place, or for any medical outcome — those depend on the people involved and on the hospital or blood centre. Nothing in these terms limits any liability that cannot be limited under Indian law.',
    ]),
    LegalSection('law', 'Governing law', [
      'These terms are governed by the laws of India. Courts in Chennai, Tamil Nadu have jurisdiction over any dispute, subject to any mandatory consumer-protection rights you have.',
    ]),
    LegalSection('changes', 'Changes to these terms', [
      'We may update these terms as the service changes. We will show the new effective date here and tell you in the app about important changes before they apply. If you keep using Rakta Bandhan after that, the updated terms apply.',
    ]),
  ],
);
