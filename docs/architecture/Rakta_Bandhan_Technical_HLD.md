# Rakta Bandhan — High-Level Technical Design (HLD)
### Live Blood Donor Mobile Application

---

## 1. Objective

Build a real-time, GPS-based app that connects patients/hospitals in urgent need of blood with nearby verified, willing donors — the "G-I-F-T" flow (Group selection → Identify donors → Fast acceptance → Time schedule) described in the initiative — using the most reliable architecture achievable with minimal operational overhead.

**Design principle:** favor managed/serverless services over self-hosted infrastructure wherever possible, to minimize operational risk (no server to babysit, patch, or scale manually) for something as time-critical as blood requests.

---

## 2. Users & Core Flows

| Role | What they do |
|---|---|
| **Donor** | Registers once (blood group, location, health eligibility), toggles available/unavailable, receives request alerts, accepts/declines, schedules donation, gets auto-reactivated 90 days after donating |
| **Requester** (patient/family/hospital staff) | Raises a request: blood group + units + location + urgency, sees a live list/map of matching donors, contacts/books one |
| **Admin** (organizing body staff) | Verifies donor accounts, moderates requests, views a dashboard of activity, manages hospital/blood-bank partner accounts |

---

## 3. Recommended Architecture

The core architectural decision is to use a managed Backend-as-a-Service (BaaS) rather than a self-hosted server, so that authentication, database, real-time sync, and push notifications don't require custom backend engineering or server maintenance.

| Layer | Recommendation | Rationale |
|---|---|---|
| **Mobile app (Android + iOS)** | **Flutter** (single codebase → both app stores) | One codebase to maintain instead of two separate native apps; mature, well-supported framework |
| **Backend / database** | **Firebase** (Firestore + Cloud Functions + Firebase Auth) | Managed, auto-scaling, no server to patch; documented high uptime; India-region hosting available for latency |
| **Real-time donor matching** | **Firestore + Geohashing (Geoflutterfire)** | Enables "find donors within N km" radius queries natively inside Firestore, without a separate GIS service |
| **Push notifications** ("real-time notification" feature) | **Firebase Cloud Messaging (FCM)** | Works reliably even when the app is backgrounded/closed |
| **SMS/OTP fallback** | **An Indian SMS gateway (e.g., MSG91)** | Needed to reach donors on basic connectivity/older phones who may miss push alerts |
| **Maps & distance calc** | **Google Maps Platform**, with **OpenStreetMap + Nominatim** as a fallback/alternative | Google Maps for polish and reliability; OSM as a dependency-free alternative for core distance/geocoding needs |
| **Hosting for admin dashboard** | **Firebase Hosting** (or a static host like Vercel/Netlify) | Simple to deploy, scales automatically |
| **File/image storage** (donor ID proof, hospital verification docs) | **Firebase Storage** | Integrates natively with Firebase Auth security rules |
| **Analytics** | **Firebase Analytics** | Standard event/usage tracking integrated with the rest of the stack |

**Why not a fully custom backend (Node/Express + a VM + Postgres)?**
More flexible long-term, but it means building auth, matching logic, and notification plumbing from scratch, and owning uptime/monitoring/patching yourself. **Recommendation: build on Firebase first; only migrate off it if a specific limitation (e.g., complex relational queries, vendor lock-in concerns) requires it.**

**Alternative to reduce vendor lock-in from day one:** **Supabase** (open-source, Postgres-based, self-hostable later). Slightly more setup work than Firebase but avoids lock-in. Worth a short technical spike before committing to either.

---

## 4. High-Level System Diagram (textual)

```
[Donor App]  <---push (FCM)--->  [Firebase Cloud Functions]  <--->  [Firestore DB]
[Requester App] <---realtime sync--->                                    |
       |                                                          [Geohash index]
       |--- SMS fallback --> [SMS Gateway] --> [Donor's basic phone]
       |
[Admin Web Dashboard] <---> [Firebase Auth + Firestore + Storage]
```

- **Firestore** holds: `donors`, `requests`, `hospitals`, `notifications`, `donation_history`.
- **Cloud Functions** handle server-side logic: matching a new request to eligible donors within radius, triggering FCM/SMS alerts, auto re-enabling a donor 90 days post-donation, and verification workflows.
- **Firebase Auth** handles phone-number OTP login.

---

## 5. Data Model

- **donors**: `uid, name, phone, blood_group, geohash, lat, lng, last_donation_date, is_available (bool), is_verified (bool)`
- **requests**: `request_id, requester_uid/hospital_id, blood_group, units_needed, urgency, geohash, lat, lng, status (open/matched/fulfilled/expired), created_at`
- **hospitals**: `hospital_id, name, address, contact, verified (bool)`
- **notifications**: `notification_id, donor_id, request_id, status (sent/accepted/declined), timestamp`
- **donation_history**: `donor_id, request_id, date, verified_by`

---

## 6. Core Request-Matching Logic (Cloud Function)

1. Requester submits a request with blood group, urgency, and location.
2. Function computes a geohash range for the target radius (e.g., 5 km, configurable).
3. Query `donors` where `blood_group` matches (including compatible types if implemented), `is_available = true`, `is_verified = true`, and `geohash` falls within the computed range.
4. Rank candidates by distance and recency of last alert (to avoid over-notifying the same donors).
5. Send FCM push (and SMS fallback if the donor hasn't opened the app recently) to the top-N candidates.
6. First donor to accept is locked in; others are notified the request is filled.
7. On completion, update `donation_history` and set `last_donation_date`, which schedules the 90-day reactivation.

---

## 7. Non-Functional Requirements

| Concern | Approach |
|---|---|
| **Reliability** | Managed backend removes most "server down" risk — important given the emergency use case |
| **Data privacy** | Blood group, health eligibility, and phone number are sensitive; Firestore security rules should reveal a donor's exact location/contact only to a matched requester after acceptance, never broadcast openly |
| **Low-connectivity tolerance** | Firestore supports offline queuing/sync natively; SMS fallback covers gaps where push notifications don't reach the donor |
| **Verification / trust** | Admin approval required before a donor or hospital account goes live, to prevent fake listings |
| **Scalability** | Firestore + Cloud Functions auto-scale without re-architecture as usage grows |

---

## 8. Suggested Build Phasing

1. **Phase 1 — Core MVP**: donor registration + OTP login, request creation, geohash-based matching, FCM alert, accept/decline, basic donor list view for requester.
2. **Phase 2 — Pilot with hospitals**: admin verification dashboard, hospital accounts, donation history, 90-day reactivation logic, SMS fallback.
3. **Phase 3 — Public rollout**: outreach integrations (QR code deep links, social sharing), analytics, load-testing before wide promotion.

---

## 9. Key Technical Risks

- **Fake/unreliable donor listings** → mitigate with admin verification + post-donation confirmation flow.
- **Notification fatigue** (donors ignoring alerts) → cap request frequency per donor, prioritize by proximity and recency of last contact.
- **Low-connectivity users left out** → SMS fallback is core to inclusivity for this use case, not optional.
- **Vendor lock-in** → mitigated by choosing Firestore's data model conservatively and keeping business logic in Cloud Functions rather than deeply Firebase-specific client code, so a future migration (e.g., to Supabase) stays feasible.
