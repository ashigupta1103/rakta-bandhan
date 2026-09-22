# Rakta Bandhan — Rotary Club Stakeholder Information Checklist

This checklist identifies the information and assets required from the Rotary Club/Rakta Bandhan stakeholders before demo content can be replaced with approved production content. Any content currently shown in the app as DEMO, SAMPLE, or PLACEHOLDER is not official.

---

## 1. Organization information

- [ ] Official project/organization name
- [ ] Official short name
- [ ] Approved mission statement
- [ ] Approved vision statement
- [ ] Short About description
- [ ] Detailed About description
- [ ] Official founding date, if it should be displayed
- [ ] Official organization registration details, if applicable
- [ ] Operational locations
- [ ] Areas served
- [ ] Official contact email
- [ ] Official contact phone number
- [ ] Official website
- [ ] Official social media links
- [ ] Emergency disclaimer
- [ ] Person responsible for approving content

## 2. Rotary Club information

- [ ] Rotary Club's official name
- [ ] Rotary district/region, if intended for display
- [ ] Club logo in SVG/PNG format
- [ ] Approved Rotary branding guidelines
- [ ] Official club description
- [ ] Club president's approved name and title, if displayed
- [ ] Project coordinator's name and role
- [ ] Approved team-member names and roles
- [ ] Approved team biographies
- [ ] Official club website and social links
- [ ] Permission to display Rotary branding
- [ ] Permission to use club photographs
- [ ] Approved partnership/association wording
- [ ] Primary contact person
- [ ] Backup contact person

> **Note on the current build:** the About screen's "THE TEAM" section already shows three names (Adarsh, Sathish Kumar, Radhika) that were entered directly by the project owner in an earlier session, not invented by this pass — they were deliberately left untouched rather than guessed at, since it's unclear from the code alone whether they're real team members' first names pending role/bio, or intended as placeholders. **This needs an explicit decision from the team**: confirm whether these are real names to keep (and supply role/bio/photo for), or whether they should be replaced with a demo-labeled placeholder until real names are approved.

## 3. Testimonials

For each testimonial, request:
- [ ] Approved display name
- [ ] Full name, provided privately if needed
- [ ] Role: donor, recipient, volunteer, coordinator, etc.
- [ ] Final approved testimonial text
- [ ] Preferred language
- [ ] Profile photograph, if applicable
- [ ] Written consent to publish testimonial
- [ ] Written consent to publish photograph
- [ ] Whether full name, first name, initials, or anonymous display is preferred
- [ ] Approximate date of experience
- [ ] Relevant location, if approved
- [ ] Whether medical or personal details may be published
- [ ] Final approval from the responsible stakeholder

> Current build: the Testimonials screen shows two testimonials explicitly labeled "Demo Donor 01" / "Demo Recipient 02" with a "DEMO" badge and an on-screen notice that they are sample layouts, not real testimonials, and must be replaced with approved content before launch (`lib/screens/testimonials_screen.dart`).

## 4. Team members and volunteers

For every person to be shown:
- [ ] Approved name
- [ ] Approved role/title
- [ ] Short biography
- [ ] Contribution description
- [ ] Profile photograph
- [ ] Permission to publish photograph
- [ ] Permission to publish name and role
- [ ] Approved social/contact links
- [ ] Preferred display format
- [ ] Final content approval

## 5. Corporate partnerships

For every partner:
- [ ] Official company/organization name
- [ ] Partnership status: proposed, active, completed, or inactive
- [ ] Partnership type
- [ ] Approved partnership description
- [ ] Official logo in SVG/PNG format
- [ ] Permission to display logo
- [ ] Permission to display company name
- [ ] Brand guidelines
- [ ] Official website
- [ ] Contact person's name
- [ ] Contact person's designation
- [ ] Official business email
- [ ] Approved CTA
- [ ] Confidentiality restrictions
- [ ] Legal approval, if required

> Current build: the Corporate Partnerships screen shows two demo partner cards ("Demo Community Partner", "Demo Healthcare Supporter"), each labeled DEMO with an "Awaiting official partner information" notice — no real company name, logo or claim is present. The "Start a conversation" CTA already shows an honest message that no real contact/lead-capture flow exists yet, rather than pretending a message was sent.

## 6. Help and support

- [ ] Official support email
- [ ] Official support phone number
- [ ] Support operating hours
- [ ] Expected response time
- [ ] Emergency escalation procedure
- [ ] Approved FAQ questions and answers
- [ ] Technical issue reporting process
- [ ] Account-related support process
- [ ] Incorrect information correction process
- [ ] User complaint process
- [ ] Responsible support team member

> Current build: the Help & Support FAQ already answers questions the code verifiably supports today (OTP sign-in, phone visibility, cooldown, creating a request, finding donors, how matching works, checking request status, the emergency disclaimer) and is explicit that contact info, an issue-reporting flow, and an incorrect-info correction process do not exist yet — nothing invented there.

## 7. Privacy, consent, and legal

Request approved documents and wording for:
- [ ] Privacy Policy
- [ ] Terms and Conditions
- [ ] User consent wording
- [ ] Location permission wording
- [ ] Photo consent wording
- [ ] Testimonial consent wording
- [ ] Data-sharing policy
- [ ] Data retention policy
- [ ] Account deletion policy
- [ ] User data correction policy
- [ ] Community guidelines
- [ ] Content reporting policy
- [ ] Medical/emergency disclaimer
- [ ] Legal organization name
- [ ] Legal contact email
- [ ] Effective date
- [ ] Document version number
- [ ] Final legal approval

> Current build: the Privacy Policy and Terms of Use screens now show a visible "Draft placeholder — awaiting approval" banner and state the content must be reviewed and approved before production release. No retention period, legal entity detail, or compliance claim has been invented.

## 8. Community content

- [ ] Approved community guidelines
- [ ] Rules for posts and comments
- [ ] Moderation responsibilities
- [ ] Reporting and blocking process
- [ ] Public profile/alias policy
- [ ] Image upload policy
- [ ] Image moderation requirements
- [ ] Prohibited content list
- [ ] Content removal procedure
- [ ] Official awareness campaigns
- [ ] Approved community announcements
- [ ] Permission to publish event photographs

> Current build: the Community screen's Stories and What's New tabs each show demo-labeled preview cards (one demo story, two demo announcements) with fictional display names and no engagement numbers — purely frontend, nothing written to Firestore. Real posting still requires the public-handle/moderation model this section is asking about.

## 9. Branding and assets

- [ ] Final logo in SVG format
- [ ] Final logo in PNG format
- [ ] App icon
- [ ] Brand color codes
- [ ] Typography guidelines
- [ ] Approved illustrations
- [ ] Approved photographs
- [ ] Testimonial photographs
- [ ] Team photographs
- [ ] Rotary Club logo
- [ ] Partner logos
- [ ] Brand usage restrictions
- [ ] Image usage permissions
- [ ] Final approved copy
- [ ] Legal documents in editable/PDF format

## 10. Features requiring stakeholder decisions

- [ ] Whether testimonials should be public or restricted
- [ ] Whether photos should be displayed
- [ ] Whether users should use full names or aliases
- [ ] Whether corporate partnerships should be public
- [ ] Whether the app needs official support chat
- [ ] Whether group funding/donation features are required
- [ ] Whether community posts require moderation before publication
- [ ] Whether certificates should be official or informational
- [ ] Who approves content before release
- [ ] Who handles emergency-related escalation
- [ ] Which features are required for the first release
- [ ] Which features can remain future enhancements

## 11. Content approval tracker

| Item | Responsible Person | Information Required | Status | Approval Needed | Deadline | Notes |
|------|--------------------|----------------------|--------|------------------|----------|-------|
| Organization name & About copy | | Section 1 | Pending | | | |
| Rotary Club details & branding | | Section 2 | Pending | | | |
| Team roster (incl. Adarsh / Sathish Kumar / Radhika) | | Section 2 note, Section 4 | Pending | | | Confirm whether existing first names are real or placeholder |
| Testimonials (2 shown as demo) | | Section 3 | Pending | | | |
| Corporate partners (2 shown as demo) | | Section 5 | Pending | | | |
| Support contact details | | Section 6 | Pending | | | |
| Privacy Policy | | Section 7 | Pending | | | |
| Terms of Use | | Section 7 | Pending | | | |
| Community guidelines | | Section 8 | Pending | | | |
| Brand assets (logo, colors, fonts) | | Section 9 | Pending | | | |
| Feature-scope decisions | | Section 10 | Pending | | | |

Statuses: Pending · Requested · Received · Under Review · Approved · Needs Changes · Not Required

## 12. Response template for Rotary Club

Copy this block per item when responding:

```
Item:
Responsible person:
Information provided:
Files attached:
Public display allowed: Yes / No / Needs confirmation
Consent required: Yes / No / Pending
Approval person:
Expected completion date:
Notes:
```

Please do not send sensitive personal information in the group. Share private information through an approved secure channel. Only content explicitly approved for public display should be used in the production app.

---

**How to use this file:** when the Rakta Bandhan/Rotary Club team supplies an item, replace its checklist line with the approved content (or a pointer to where it now lives) and check it off in the tracker above. Do not fill any item in this file with placeholder or invented content.
