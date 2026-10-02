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

// DRAFT — written to match what the app actually does (see
// lib/services/*.dart, functions/src/index.ts and backend/*.rules), using
// the wording supplied by the Rakta Bandhan team where it applies. Not
// legal advice; must be reviewed by counsel before kLegalApproved is set.
// If app behaviour changes, update the matching section here in the same
// change, and re-run tool/export_legal_html.py.

const privacyPolicy = LegalDocument(
  title: 'Privacy policy',
  intro:
      'Rakta Bandhan is a humanitarian initiative that connects people who urgently need blood with willing donors nearby. Rakta Bandhan respects your privacy and is committed to protecting the information you provide. To do its job it handles sensitive things — your phone number, where you are and your blood group. This policy explains what we collect, who can see it, and how to get it back or deleted.',
  summary: [
    'Your phone number and email are never shown to other users. Matched people reach each other through in-app messages and calls.',
    'Other users see your neighbourhood (for example “Adyar, Chennai”, about 1 km), never your address.',
    'Location is used only while you use the app — never tracked in the background.',
    'Chat and calls happen inside the app. Calls are not recorded.',
    'We don’t sell your data or show ads.',
    'You can download your data or delete your account from Settings at any time.',
  ],
  sections: [
    LegalSection('who', 'Who we are', [
      'Rakta Bandhan is a not-for-profit, collaborative service project of $kLegalEntity, $kLegalCity, India, managed by $kLegalOperators, with support from Rotary International District 3233. For the purposes of the Digital Personal Data Protection Act, 2023 (DPDP Act), we are the Data Fiduciary for the personal data described here.',
    ]),
    LegalSection('collect', 'What we collect', [
      'Account and profile — what you give us:',
      '- Your email address, used to sign you in. Each time you sign in we email you a one-time 6-digit code; there is no password. A code works once, expires after 10 minutes, and we keep it only in hashed form.',
      '- Sign-in safeguards: to stop abuse we keep a small record holding a hash of your email address (not the address itself), when we last sent you a code, how many codes were sent today and how many wrong tries were made. We also count sign-in requests per network, using a hash of the IP address.',
      '- Your name and mobile number. Your number is never shown to other users — matched people reach each other through in-app messages and calls.',
      '- Your unique username and the date it was last changed. Usernames are visible to signed-in members on profiles, community posts and matched chats; changes are limited to once every 30 days.',
      '- Your blood group.',
      '- The area you register from: a location label you choose and its map coordinates.',
      '- Whether you are available to donate, and the date of your last donation recorded in the app.',
      '- Optionally, a photo of an ID document, if you submit one for verification.',
      '- Optionally, a profile photo. Its link is kept in your private profile and the app shows it only to you. Anyone you give the photo link to can open it.',
      'Requests — when you ask for blood: the blood group and number of units needed, how urgent it is, the location (usually a hospital) and its coordinates, and the request’s status over time.',
      'Conversations — when you are matched: the messages you send in the in-app chat, any location you choose to share in it (the hospital, or your position at that moment — never tracked continuously), when you last read the conversation (shown to the other person as “Seen”), and a record of in-app calls (who called whom, when, how long, and whether it was answered). The audio of calls is never recorded or stored.',
      'Community posts — if you share an experience: the text, the topic, and optionally one photo, your blood group and your neighbourhood if you choose to show them.',
      'Safety reports — if you report someone or a post: the reason you chose and any details you add.',
      'App usage — through Google Firebase Analytics: a small set of events (such as registering, creating a request, being matched, completing a donation), plus information Firebase collects automatically such as an app-instance identifier, device model, operating system, and approximate region derived from your IP address.',
      'Notification settings — whether you turned on urgent alerts and, if you allowed notifications, a push-notification token for your device. We use it to tell you about new messages, calls, nearby requests you can help with, and updates on your own requests.',
    ]),
    LegalSection('use', 'How we use it', [
      '- To match requests with compatible donors nearby — using blood group, approximate location and availability — and to notify suitable donors about a blood requirement.',
      '- To connect donors with the requesting party or hospital, and to communicate important service-related notifications.',
      '- To let a matched requester and donor reach each other through in-app chat and calls, without sharing phone numbers.',
      '- To verify donors, when an administrator reviews a submitted ID.',
      '- To enforce the donation cooldown (90 days after a donation recorded in the app) and to expire requests that go unanswered for 6 hours.',
      '- To keep people safe and prevent misuse or fraudulent activity: reviewing reports, and suspending accounts that misuse the service.',
      '- To improve the functionality and security of the platform.',
      '- To understand, in aggregate, whether the service is working (for example how many requests get matched).',
      'We do not use your data for advertising, and we do not sell or rent it to anyone.',
    ]),
    LegalSection('visible', 'What other people can see', [
      'Any signed-in user can see, for donors who are available: first and last name as registered, blood group, verification status, their neighbourhood name, and a location rounded to about 1 km. This is how requesters find donors on the map.',
      'Any signed-in user can see open requests: the blood group and units needed, urgency, and the request’s location.',
      'Only after a match — when a donor accepts a request — the two people involved can see each other’s name, message each other in the app, and call each other in the app. Phone numbers stay in private profiles, accessible only to the owner and administrators. Nobody else can see that conversation. Tapping a shared location opens it in your maps app (for example Google Maps), which then handles it under its own privacy terms.',
      'In-app call audio travels directly between the two phones, or through an encrypted Cloudflare TURN relay when needed. A direct connection can reveal the other phone’s network (IP) address for the duration of the call; it does not reveal a phone number. The relay sees network addresses but cannot read the encrypted audio.',
      'Community posts are visible to every signed-in user, under your first name and @username. Older posts may still show the registered name. Anyone with a community photo’s link can open the photo.',
      'We share information with hospitals, blood banks or service partners only to the extent necessary to facilitate a blood request or operate the platform, and as the law allows. We will not sell personal information to third parties.',
    ]),
    LegalSection('admins', 'What our administrators can see', [
      'A small team of Rakta Bandhan administrators can see donor profiles including phone numbers, submitted ID photos, requests, and safety reports. They can read the chat on a request to review a report of abuse. Administrators cannot listen to calls — there is no recording to listen to. Every verification, ban and administrative change is written to an audit log.',
    ]),
    LegalSection('processors', 'Services we rely on', [
      '- Google Firebase (Google LLC) — sign-in, the database that stores profiles, requests and messages, server functions that send notifications and sign-in codes once enabled, Firebase Cloud Messaging (push notifications) and analytics. Legacy ID photos may remain in the database until verified or deleted. Data is stored on Google Cloud servers, which may be located outside India.',
      '- Cloudflare — Workers handle photo uploads, downloads and deletions; R2 stores community, profile and ID photos. Private ID-photo downloads require your sign-in or an administrator’s sign-in. Cloudflare Realtime TURN relays encrypted call audio when a direct connection is unavailable. Cloudflare sees the network addresses of these requests. Data may be processed outside India.',
      '- Our email-delivery provider (Resend) — delivers the sign-in code email. It sees your email address and the message.',
      '- OpenStreetMap — when you search for an address, the text you type is sent to the OpenStreetMap Foundation’s Nominatim service. When you use your current location to fill in an address, your coordinates are sent to that service to look up the street name. Map images are loaded from OpenStreetMap’s tile servers, which see your IP address and the area of the map you are viewing.',
      '- Google’s public STUN servers — used for a moment at the start of each in-app call to help the two phones find each other. They see your IP address, not the call.',
      'These providers process data under their own privacy terms. We do not give your data to anyone else, except where the law requires it — for example a valid order from a court or government authority.',
    ]),
    LegalSection('retention', 'How long we keep it', [
      '- Your profile is kept for as long as your account exists.',
      '- An ID photo you submit is deleted as soon as an administrator has checked it; we keep only the fact and date it was checked.',
      '- Requests, chat messages and call records are kept as part of the request’s history so both people have a record of what happened.',
      '- Community posts stay until you or an administrator delete them; deleting a post deletes its photo.',
      '- A profile photo stays until you remove or replace it in My Page.',
      '- When you delete your account, we delete your sign-in account, your profile, your public listing, any ID photo, your profile photo, and every chat message you sent. Requests you raised are cancelled if still open, and your name is removed from them. Legacy phone fields, if present, are removed rather than copied. If you were matched as a donor on an open request, that request is released back to other donors. A record that a donation happened is kept without your name or phone number.',
      '- Analytics data is kept for the retention period set in Firebase Analytics: [ORGANIZATION TO PROVIDE — confirm the configured period].',
    ]),
    LegalSection('rights', 'Your rights', [
      'Under the DPDP Act you have the right to:',
      '- Access your data — Settings › Download my data gives you a copy of everything stored against your account.',
      '- Correct it — edit your name and number in the app, or contact us and we will fix anything that is wrong.',
      '- Erase it — Settings › Delete my account removes your account immediately, as described above.',
      '- Withdraw consent — turn off availability or urgent alerts at any time, or delete your account. Withdrawing consent doesn’t affect anything done before you withdrew it.',
      '- Grievance redressal — raise a complaint with our Grievance Officer (below), and if you are not satisfied, with the Data Protection Board of India.',
      '- Nominate someone to exercise these rights on your behalf in the event of death or incapacity.',
    ]),
    LegalSection('security', 'How we protect it', [
      'We adopt reasonable technical and organisational measures to protect personal information from unauthorised access, alteration, disclosure or misuse. Data is encrypted in transit and at rest by Google Cloud. Only accounts that have confirmed their email with a sign-in code can post requests, message or call. Access is enforced by database security rules: your phone number and ID photo sit in a private record only you and administrators can read, and the public donor listing never contains a phone number. In-app calls are encrypted end to end between the two phones (WebRTC DTLS-SRTP). No system is perfectly secure; if a breach affects you, we will tell you and the Data Protection Board as the law requires.',
    ]),
    LegalSection('children', 'Age limit', [
      'Rakta Bandhan is for people aged 18 and over — the minimum age to donate blood in India. It is not intended for use by children, and we do not knowingly collect data from anyone under 18. A parent or guardian may raise a request on a child’s behalf from their own account. If you believe a child has registered, contact us and we will delete the account.',
    ]),
    LegalSection('changes', 'Changes to this policy', [
      'This policy may be updated periodically. If we change how we handle your data, we will update this page and its effective date, make the latest version available in the app, and tell you before the change takes effect when it matters to you.',
    ]),
  ],
);

const termsOfUse = LegalDocument(
  title: 'Terms of use',
  intro:
      'These terms are the agreement between you and Rakta Bandhan, a service project of $kLegalEntity. By accessing or using Rakta Bandhan you agree to them. Please read the section on what Rakta Bandhan is not — it matters in an emergency.',
  summary: [
    'Rakta Bandhan helps people find each other. It is not a blood bank, hospital or medical service.',
    'Donations happen only at licensed blood centres and hospitals, whose medical staff decide who can donate.',
    'Blood must never be bought or sold. Anyone who asks for or offers money is removed.',
    'In a medical emergency, call 108 or 112 first.',
  ],
  sections: [
    LegalSection('eligibility', 'Who can use Rakta Bandhan', [
      '- You must be at least 18 years old.',
      '- You must give accurate information — especially your name, contact details, blood group, availability, location and donation-related information — and must not deliberately provide false or misleading information.',
      '- One account per person. Your account is personal; don’t let anyone else use it.',
    ]),
    LegalSection('not', 'What Rakta Bandhan is — and is not', [
      'Rakta Bandhan is a platform that lets someone who needs blood reach willing, compatible donors nearby, and lets them contact each other.',
      'It is not a blood bank, hospital, laboratory or medical provider. We do not collect, test, store, process or transfuse blood, and we give no medical advice.',
      '- Blood compatibility shown in the app is a guide for matching only. Testing and cross-matching are always done by the blood centre.',
      '- Rakta Bandhan does not determine anyone’s medical eligibility to donate. Donors must meet the applicable medical and blood-donation eligibility requirements and follow the advice and verification procedures of the hospital, blood bank or medical professional. A “verified” badge means an administrator checked an ID — it is not a medical clearance.',
      '- A donor is always free to choose whether or not to respond to a request.',
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
      '- try to access accounts, data or parts of the service that aren’t yours, or interfere with how it works;',
      '- misuse donor information, spam or misuse notifications, or use the platform for anything unlawful.',
      'Community posts must follow the Community guidelines. You keep ownership of what you post, and allow Rakta Bandhan to show it to other users in the app.',
      'You can report and block anyone from the chat menu. Blocking closes the conversation for both people.',
    ]),
    LegalSection('alerts', 'Urgent alerts', [
      'If you turn on urgent alerts, your phone may play a sound and show a full-screen alert when an urgent, compatible request is raised near you. They are best effort — an alert may be delayed or not arrive, for example if the app is closed, your phone is offline, or notifications are blocked. You can turn them off at any time.',
    ]),
    LegalSection('suspension', 'Suspension and removal', [
      'We may verify, restrict, suspend or remove an account, or remove content, where there is suspected misuse, fraudulent activity or a breach of these terms — usually after reviewing a report — and may refer suspected unlawful activity to the appropriate authority. You can stop using Rakta Bandhan and delete your account at any time from Settings.',
    ]),
    LegalSection('liability', 'Disclaimers and liability', [
      'Rakta Bandhan will endeavour to keep the platform available but does not guarantee uninterrupted availability or a successful donor match in every situation. It facilitates connections and information exchange; it does not provide medical diagnosis, treatment or advice. Rakta Bandhan is provided free of charge by volunteers, “as is” and “as available”. To the extent the law allows, we are not liable for the acts or omissions of any user, for whether a donation takes place, or for any medical outcome — those depend on the people involved and on the hospital or blood centre. Nothing in these terms limits any liability that cannot be limited under Indian law.',
    ]),
    LegalSection('law', 'Governing law', [
      'These terms are governed by the laws of India. Courts in Chennai, Tamil Nadu have jurisdiction over any dispute, subject to any mandatory consumer-protection rights you have.',
    ]),
    LegalSection('changes', 'Changes to these terms', [
      'We may update these terms as the service changes. We will show the new effective date here and tell you in the app about important changes before they apply. If you keep using Rakta Bandhan after that, the updated terms apply.',
    ]),
  ],
);

const communityGuidelines = LegalDocument(
  title: 'Community guidelines',
  intro:
      'Rakta Bandhan connects real people during stressful medical situations. These guidelines apply to requests, chats, calls and community posts. Give responsibly. Ask respectfully. Protect privacy. Save lives.',
  summary: [
    'Be respectful to donors, patients, caregivers and hospitals.',
    'Never offer, ask for or negotiate money for blood.',
    'Never post someone’s phone number, address or medical details.',
    'Report anything suspicious from the chat or post menu.',
  ],
  sections: [
    LegalSection('respect', 'Respect', [
      'Treat donors, patients, caregivers, hospitals and other users respectfully.',
    ]),
    LegalSection('money', 'No commercial blood transactions', [
      'Rakta Bandhan exists for voluntary blood donation. Do not offer, demand or negotiate payment for blood through the platform.',
    ]),
    LegalSection('harassment', 'No harassment', [
      'Do not threaten, abuse, repeatedly contact or pressure a donor or requester. A donor is always free to say no.',
    ]),
    LegalSection('privacy', 'Protect personal information', [
      'Do not publicly post another person’s phone number, address, medical information or other private information without their permission.',
    ]),
    LegalSection('accuracy', 'Accurate information', [
      'Keep your blood group, location, availability and request details accurate.',
    ]),
    LegalSection('genuine', 'Genuine requests only', [
      'Do not create fake, duplicate or misleading blood requests.',
    ]),
    LegalSection('spam', 'No spam', [
      'No promotional messages, advertisements, unrelated fundraising, chain messages or unsolicited commercial content.',
    ]),
    LegalSection('report', 'Report misuse', [
      'Report suspicious, fraudulent or inappropriate activity from the chat menu, the post menu, or Help & support. Reports go to our moderation team.',
    ]),
    LegalSection('action', 'What we may do', [
      'Depending on how serious a violation is, Rakta Bandhan may:',
      '- remove inappropriate content;',
      '- restrict communication;',
      '- temporarily suspend an account;',
      '- permanently deactivate an account;',
      '- refer suspected unlawful activity to the appropriate authority where required.',
    ]),
  ],
);
