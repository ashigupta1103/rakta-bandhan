import 'package:flutter/material.dart';
import '../../widgets/legal_document_page.dart';

/// PLACEHOLDER CONTENT — product-descriptive, not legal advice, not
/// reviewed by a legal advisor. Describes only behaviour that the app
/// actually implements today (see services/backend.dart). Replace wholesale
/// with approved copy before any public release.
class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const LegalDocumentPage(
      title: 'Terms & Conditions',
      lastUpdated: 'August 2026',
      intro:
          'These terms describe what Rakta Bandhan does, what we ask of you, and the limits of the service. Rakta Bandhan connects people who need blood with people willing to donate it. It is a coordination tool — not a medical provider, blood bank, or emergency service.',
      sections: [
        LegalSection(
          'Not a medical or emergency service',
          'Rakta Bandhan does not collect, test, store, transport or administer blood. All donation and transfusion takes place at a licensed medical facility, under its supervision and rules. In a medical emergency, contact emergency services first — do not rely on this app.',
        ),
        LegalSection(
          'Eligibility',
          'You must be legally able to donate blood in your jurisdiction and meet the medical eligibility criteria of the facility performing the donation. Rakta Bandhan does not assess your medical fitness to donate. The final decision always rests with the medical staff at the donation site.',
        ),
        LegalSection(
          'Accurate information',
          'You agree that the name, phone number, blood group and location you provide are accurate and belong to you. Incorrect blood group information can cause real harm to a person in need. Accounts found to be supplying false information may be suspended by an administrator.',
        ),
        LegalSection(
          'Donation is always voluntary',
          'Accepting a request through the app is an expression of intent, not a binding commitment. You may withdraw at any point before donating. Equally, no one is entitled to your blood, your time, or your contact details.',
        ),
        LegalSection(
          'No payment for blood',
          'Rakta Bandhan is a free service and does not facilitate payment for blood or blood products. Requesting or offering payment in exchange for a donation is not permitted and may be unlawful.',
        ),
        LegalSection(
          'Verification and suspension',
          'Administrators may verify, suspend or remove accounts to protect the integrity of the network — for example where a profile appears fraudulent, abusive, or repeatedly fails to honour accepted requests.',
        ),
        LegalSection(
          'Availability of the service',
          'We aim to keep the service running but cannot guarantee uninterrupted availability, that a compatible donor will be found, or that any request will be fulfilled within a given time.',
        ),
        LegalSection(
          'Changes to these terms',
          'If these terms change materially, you will be asked to review them in the app before continuing to use the service.',
        ),
      ],
    );
  }
}
