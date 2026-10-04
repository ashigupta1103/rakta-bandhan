import 'package:flutter/material.dart';
import '../../widgets/legal_document_page.dart';

/// PLACEHOLDER CONTENT — product-descriptive, not legal advice, not
/// reviewed by a legal advisor. Every statement below reflects behaviour
/// implemented in services/backend.dart today. Replace wholesale with
/// approved copy before any public release.
class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const LegalDocumentPage(
      title: 'Privacy Policy',
      lastUpdated: 'August 2026',
      intro:
          'Rakta Bandhan handles two genuinely sensitive things: your phone number and your location. This policy explains what we hold, who can see it, and how you get it back or removed.',
      sections: [
        LegalSection(
          'What we hold',
          'Your name, phone number, blood group, and an approximate latitude/longitude for your area. For each request you raise: the blood group needed, units, urgency, the location label you chose, and the request status. For each donation you complete: the date, used to calculate your donation cooldown.',
        ),
        LegalSection(
          'Who can see your phone number',
          'Nobody, by default. Your number is not shown in donor lists, on the map, or on your public profile. It is revealed to one other person only at the moment a request is accepted — the requester sees the matched donor\'s number and vice versa — so that the two of you can arrange the donation.',
        ),
        LegalSection(
          'How your location is shown',
          'Other users never see your coordinates or address. They see a distance, calculated from your approximate position. Your coordinates are stored so that distance can be computed and so requests near you can reach you.',
        ),
        LegalSection(
          'Notifications',
          'If you allow notifications, we use them to tell you about compatible requests near you, matches, cancellations and expiries. You can turn these off at any time in Consent preferences or in your device settings.',
        ),
        LegalSection(
          'Analytics',
          'The app currently ships with no analytics or advertising SDK. If that changes, analytics will be off until you switch it on in Consent preferences, and this policy will be updated first.',
        ),
        LegalSection(
          'Retention',
          'Your donor profile is kept while your account exists. Requests are retained as part of your request history so you and the people you were matched with have a record of what happened.',
        ),
        LegalSection(
          'Your rights',
          'You can view what we hold from Profile, export a copy from Settings, withdraw individual consents from Consent preferences, and request deletion of your account and data from Settings. Rakta Bandhan intends to operate in line with the Digital Personal Data Protection Act, 2023.',
        ),
        LegalSection(
          'Contact',
          'Questions about your data, or a deletion request that has not been actioned, should go to the Rakta Bandhan administrator team. Contact details are on the About screen.',
        ),
      ],
    );
  }
}
