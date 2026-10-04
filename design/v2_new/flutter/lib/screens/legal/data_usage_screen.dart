import 'package:flutter/material.dart';
import '../../widgets/legal_document_page.dart';

/// PLACEHOLDER CONTENT — product-descriptive, not legal advice, not
/// reviewed by a legal advisor. A plain-language companion to the Privacy
/// Policy: what each field is for, stated per field.
class DataUsageScreen extends StatelessWidget {
  const DataUsageScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const LegalDocumentPage(
      title: 'Data Usage',
      lastUpdated: 'August 2026',
      intro:
          'A field-by-field breakdown of what Rakta Bandhan collects and why. If a piece of information is not listed here, the app does not collect it.',
      sections: [
        LegalSection(
          'Name',
          'Shown to the person you are matched with so they know who to expect. Visible in donor lists as your display name.',
        ),
        LegalSection(
          'Phone number',
          'Used to sign you in, and shared with one other person only after a request is accepted. Never listed publicly.',
        ),
        LegalSection(
          'Blood group',
          'Used to match you against compatible requests. Visible to others, as it is the basis of the whole service.',
        ),
        LegalSection(
          'Approximate location',
          'Used to compute distance and to decide which requests reach you. Others see the resulting distance only.',
        ),
        LegalSection(
          'Availability status',
          'Tells the system whether to include you in matching. You control this from Profile, and it switches off automatically for 90 days after a donation.',
        ),
        LegalSection(
          'Donation dates',
          'Used to run your 90-day recovery cooldown and to show your donation count. Not shared with other users.',
        ),
        LegalSection(
          'Request records',
          'Blood group, units, urgency, location label and status for requests you raise. Visible to compatible donors nearby while the request is open.',
        ),
        LegalSection(
          'What we do not collect',
          'No medical history, no test results, no identity documents, no payment information, no contacts list, and no continuous background location tracking.',
        ),
      ],
    );
  }
}
