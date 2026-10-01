/// Facts the legal documents depend on that only the Rakta Bandhan /
/// Rotary team can supply. Fill these, have the text in
/// `legal_documents.dart` reviewed by a lawyer, then flip [kLegalApproved]
/// — until then every legal page shows a "draft" banner, so unreviewed
/// text is never presented as a policy in force.
library;

const kLegalApproved = false;

const kLegalVersion = '1.1';
const kLegalEffectiveDate = '1 October 2026';

/// The data fiduciary (DPDP Act, 2023) — the organisations responsible.
/// Rakta Bandhan is a collaborative service project of these two trusts,
/// managed by Rotary Club of Madras Cosmos and Rotary Club of Chennai
/// Capital, with support from Rotary International District 3233.
const kLegalEntity = 'Madras Cosmos Charitable Trust and Chennai Capital Trust';
const kLegalOperators = 'Rotary Club of Madras Cosmos and Rotary Club of Chennai Capital';
const kLegalCity = 'Chennai, Tamil Nadu';

/// Required before launch: a monitored inbox for privacy requests, and the
/// name of the Grievance Officer (IT Rules 2011 / DPDP Act, 2023). App
/// Store and Play listings also need a public web URL for the privacy
/// policy and for account-deletion requests.
const kLegalContactEmail = '';
const kGrievanceOfficerName = '';
