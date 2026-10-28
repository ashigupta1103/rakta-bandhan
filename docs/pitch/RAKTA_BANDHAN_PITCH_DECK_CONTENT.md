# Rakta Bandhan: pitch deck content

**Audience:** potential funding partners (CSR and donors), hospitals and blood banks, and Rotary, Rotaract and Lions clubs.
**Length:** 14 slides plus a 4-slide appendix. A 10-slide cut is at the end.
**Send it as:** a PDF named `Rakta Bandhan 20261005.pdf`.
**Written to the advice in the pitch-deck repo** (YC, Kawasaki, 500 Startups, Atrium, Teten, Dyuk): lead with the problem, one idea per slide, big numbers instead of bullets, real product screens, risks shown early, an ask tied to milestones.

**One-liner (for the cover note and the first 10 seconds):**
A mobile app that helps patients' families and hospitals find a compatible blood donor nearby, within minutes, by alerting available donors and connecting them privately, built as a service project of the Rotary Clubs of Madras Cosmos and Chennai Capital.

**Look:** warm paper background `#FCF8F2`, text `#241413`, red `#B81E14`, gold `#E0A030`. Headlines in Newsreader, body in Barlow. Body text 24 pt or larger, at most 5 bullets a slide, page number bottom right.

---

## Slide 1. Cover

**On the slide**
- **Rakta Bandhan**
- When blood is needed, a nearby donor is one tap away.
- *A bond of humanity, tied by blood.*
- A service project of Madras Cosmos Charitable Trust and Chennai Capital Trust. Run by the Rotary Clubs of Madras Cosmos and Chennai Capital.
- Partner and funder briefing, October 2026
- Contact: [name, email, phone]

**Visual:** the droplet-and-heart mark only (`assets/branding/app-icon-1024.png`).
**Say:** Ten seconds. Who we are and what we do.

---

## Slide 2. The hook

**On the slide**
- **In 10 minutes you can get groceries. Not a blood donor.**
- Getting what we need, now, is easy. Finding the right blood donor in time is not.

**Say:** This is the founding insight. The project chairman conceived Rakta Bandhan "from the thought that reaching a blood donor should be faster and more seamless in an emergency."
**Source:** Founding deck, May 2025; About page of the app.

---

## Slide 3. The gap, in numbers

**On the slide** (three big numbers)
- **14.6 million units**: India's estimated yearly need.
- **14.6 million units**: collected in 2024–25, up 15% on the year before.
- **26%**: in eight northern states, the share of people within 30 minutes of a blood bank. (61% within 60 minutes.)
- Line under them: *About 3 in 10 units still come through replacement donors: the patient's own family and friends.*

**Title:** Enough blood exists. Reaching it in time is the gap.
**Say:** Nationally, collection now roughly matches need. The pain is distribution, timing, and families scrambling to find someone. The 26% figure covers eight northern states, so we use it to show the nature of the gap. It does not describe Chennai, where we start.
**Sources (on the slide, small):** WHO India (14.6 million units a year); ORF, 4 Oct 2025, citing the Government's statement in Parliament, Aug 2025 (14,601,147 units in 2024–25 against 12,695,363 the year before; about 70% voluntary, about 30% replacement); Kundu et al., BMJ Global Health 2024, DOI 10.1136/bmjgh-2024-015637.

---

## Slide 4. The solution

**Title:** Rakta Bandhan puts the request in front of the right donors, instantly.
**On the slide** (five steps, one icon each)
1. **Ask**: raise a request with blood group, units, urgency and hospital.
2. **Alert**: compatible, available donors nearby are notified.
3. **Accept**: one donor taps accept. The match is locked.
4. **Talk**: chat or call inside the app. No phone numbers shown.
5. **Confirm**: both confirm the donation. The donor rests 90 days, then returns.
- Footer: *Free to use for patients, donors and hospitals.*

**Say:** Same flow as the founding "G-I-F-T" idea: Group, Identify, Fast acceptance, Track. The 90-day rest is automatic, so donors are never over-asked.

---

## Slide 5. The product

**Title:** See it. Accept it. Talk. Done.
**On the slide:** four phone screens with 4 to 6 word captions.
- A nearby request, most urgent first
- You're connected
- Donors near you, no numbers shown
- A certificate for every donation

**Visual files:** `build/e2e_donor/04_requests_near_you.png`, `07_match_contact.png`, `14_find_map.png`, `13_certificate.png` (see "Fix before showing" below).
**60-second demo:** requester raises an urgent A+ request, then on the donor's phone open the card, accept, then message or call, then both confirm and the certificate appears.

---

## Slide 6. Trust and safety

**Title:** Built so people feel safe asking and giving.
**On the slide** (six tiles)
- **Numbers stay private.** Phone numbers are never shown to anyone.
- **Location is approximate.** An area name and about 1 km, never an address.
- **Only the two matched people** can chat or call. Calls are never recorded.
- **Report and block** in every chat. Every community post can be reported.
- **Verified by people.** Volunteers check an ID. The photo is then deleted. Verified donors carry a badge.
- **Your data is yours.** Export it or delete your account inside the app.
- Line under them: ***Blood is never bought or sold.***

**Say:** The privacy policy and terms are written and under review. Account deletion and report-and-block are also what Google Play and the App Store require.

---

## Slide 7. Where we are

**Title:** Built end to end, tested, ready for a pilot.
**On the slide**
- **231** automated tests passing (96 app, 82 security rules, 27 and 26 backend)
- **6 of 6** automated checks green on the latest release
- **Android app + admin website + secure backend**, running on free tiers today
- Honest line: **Not public yet. The pilot is next.**

**Say:** What works today: request, match, chat and call, two-sided confirmation, certificate, urgent alerts, community stories and testimonials, admin tools for verification, moderation and support. What is still simulated: email and phone verification. That is the first thing the funding fixes.

---

## Slide 8. How we reach people

**Title:** Start where Rotary already is.
**On the slide**
- Pilot with **selected hospitals** in Chennai
- Register donors at **blood camps** and Rotary and Rotaract events
- **QR codes** at hospitals, malls, events and partner venues
- **Rotary digital channels** and partner amplification
- Corporate volunteer programmes and wellness venues

**Visual:** a ring diagram: hospitals, blood banks, clubs, corporates around the app.
**Say:** All of this comes from the founding outreach plan. We begin in one city and grow with the network.

---

## Slide 9. Where we fit

**Title:** Not a stock portal. Not a donor list. A live match.
**On the slide** (table)

| Today | Good for | Gap in an emergency |
|---|---|---|
| Forwarded group messages | Quick to send | No one knows who is compatible, nearby or free. No privacy |
| Calling blood banks one by one | Official stock | Slow. Stock data is only as fresh as the last update (in the eight states studied, 22% of banks did not update regularly) |
| e-RaktKosh (Government of India) | National blood-bank inventory and management | Complements us: it finds a bank with stock, we find a person nearby |
| A plain donor list | Names to try | No live availability, no one-accept lock, no rest period |

- Bottom line: ***Rakta Bandhan works alongside blood banks and e-RaktKosh, not instead of them.***

**Sources:** Government platform description (C-DAC); ORF, Oct 2025; Kundu et al., BMJ Global Health 2024.

---

## Slide 10. Who pays

**Title:** Free for everyone who needs or gives blood.
**On the slide**
- **About ₹40,000 a year** to run, even at 1 lakh sign-ups. **About ₹23,000 a year** after year one.
- Bar chart of the ₹40,000: store accounts ₹12,000, donor verification ₹13,300, database ₹8,000, cloud functions ₹500, reserve ₹6,200.
- Funded by partner and CSR support. No fees to patients, donors or hospitals. Sponsor terms to be agreed with the trusts.
- Footnote: estimate, year 1, includes GST, assumes 1,00,000 sign-ups and ₹96 to the dollar.

**Say:** Open numbers build trust. The maps, push, call relay and hosting fit inside free tiers.

---

## Slide 11. Roadmap

**Title:** The build is done. Pilot, then public launch.
**On the slide**
- **1. Build:** done. App, admin site, security, tests.
- **2. Pilot** with selected hospitals in Chennai. First, four things:
  - real email and phone verification
  - alerts that reach a closed phone
  - store accounts in the club's name
  - legal review of the privacy policy and terms
- **3. Public rollout** with media and institutional backing.
- **What we will measure in the pilot:** time to an accepted donor, share of requests matched, donations completed, donors returning after 90 days. [targets agreed with pilot hospitals]

**Say:** Be plain about the four pre-pilot items. They are exactly what the ask pays for.

---

## Slide 12. Risks, and what we do

**Title:** What could go wrong, and our answer.
**On the slide**
- **Too few donors in an area.** Start in one city. Register at camps and through Rotary.
- **Misuse** (money asked, fake requests). Report and block, admin review, a full audit log, bans.
- **Sign-ups not verified yet.** Real verification is the first milestone.
- **Alerts don't reach a closed phone yet.** A paid plan fixes it. It is in the budget.
- **Privacy and legal.** Policy drafted. Counsel review before launch.
- **Not a medical service.** The app says so and points to 108 and 112 in an emergency.

**Say:** Say these first. Investors and partners trust a team that names its own risks.

---

## Slide 13. The team

**Title:** Led by the Rotary Clubs of Madras Cosmos and Chennai Capital.
**On the slide**
- **PHF Rtn. Radhika Dhruv:** Project Chairman, Visionary and Principal Sponsor. Immediate Past President, Rotary Club of Madras Cosmos.
- **CSK:** Management Trustee, Rakta Bandhan project trust.
- **Adarsh Betala:** President, Rakta Bandhan.
- **Technology:** Platform by Almmatix (as credited in the app).
- **Partners:** [hospitals, blood banks and corporates to be named]

**Note:** each person must approve their line before this goes out.

---

## Slide 14. The ask

**Title:** Join us as a founding partner.
**On the slide** (three columns)
1. **Fund the launch year: ₹1,40,000** [confirm with the trusts]. ₹40,000 to run the service for a year, plus ₹1,00,000 for outreach (QR kits, events, social). It unlocks real verification, closed-phone alerts, store launch and the pilot.
2. **Open your doors.** Hospitals and blood banks: join the pilot and name one contact.
3. **Spread the word.** Rotary, Rotaract, Lions and corporate teams: host a donor drive and register donors.
- Contact: [name, email, phone] · rakta-bandhan-india.web.app/app

**Say:** Close on the three asks, then stop talking.

---

## Appendix

**A1. What is built:** the full request journey; urgent alerts; in-app chat and calls; donor rest period; certificates; community stories and testimonials; help, reports and replies; data export and deletion; an admin website for verification, moderation, support and settings.
**A2. Privacy by design:** two profiles per donor (private and public); phone numbers never copied to requests; rounded public location; chat only between matched people; ID photo deleted after checking; in-app export and deletion.
**A3. Cost detail:** the table behind slide 10, with assumptions.
**A4. Sources:** WHO India, blood products page; ORF, "Securing India's Lifeblood for a Reliable National Blood Supply" (K. S. Uplabdh Gopal, 4 Oct 2025); Kundu et al., "Defining blood deserts and access to blood products for 660 million people", BMJ Global Health 2024, DOI 10.1136/bmjgh-2024-015637; C-DAC e-RaktKosh overview; the May 2025 founding deck.

---

## Likely questions (one-line answers)

- **Can anyone see my number?** No. It stays on your private profile.
- **What if no donor is nearby?** The request stays open 6 hours. Donors in range are alerted. You can also browse donors on the map.
- **Does it ring a locked phone?** Not yet. Closed-phone alerts need the paid plan, which is in the budget. Today it works while the app is open.
- **Why not just e-RaktKosh?** It finds blood banks with stock. We find a person nearby, right now. They work together.
- **How do you stop misuse?** Report and block, admin review, bans, and an audit log.
- **When does it launch?** After the four pre-pilot items. The date is set with the trusts.

## 10-slide cut

Keep slides 1, 2 and 3 as one, 4, 5, 6, 8, 10, 11, 13 and 14. Move 7, 9 and 12 to the appendix.

## Cover note (one page, as the repo advises)

Subject: Rakta Bandhan 20261005: a live-donor matching app by the Rotary Clubs of Madras Cosmos and Chennai Capital.
Attach the PDF. Three lines: what it is (the one-liner), where it stands (built and tested, pilot next), what you are asking (₹1,40,000 and hospital and club partners). Name, website, location (Chennai), contact.

---

## Fill in before sending

- Contact name, email and phone (slides 1 and 14).
- The ask total on slide 14 (draft: ₹40,000 + ₹1,00,000).
- Team lines, and each person's approval (slide 13). The full name for "CSK".
- Pilot hospital and partner names (slides 8 and 13).
- Pilot targets (slide 11).

## Fix before showing

- **Screenshot data is test data.** `04` shows a real hospital's name (Apollo, Greams Road), which could read as a partnership. `07` and `08` say "Priya (test)". `13` says "Test Donor". Re-shoot with a demo account using realistic, fictional names and a neutral hospital name.
- **The certificate (`13`) shows the logo with the Rotary wheel.** Confirm the club's right to use it, or crop to the droplet-and-heart mark.
- **Slide 3's 26% figure covers eight northern states, not India.** Keep the label.
