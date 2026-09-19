# Rakta Bandhan — Admin Backend Architecture & API Reference

> **Status:** Build ✅ · 14 Cloud Functions ✅ · Firestore Rules ✅ · React Frontend ✅  
> **Last Updated:** August 2026

---

## Table of Contents
1. [Architecture Overview](#1-architecture-overview)
2. [Firestore Collections Schema](#2-firestore-collections-schema)
3. [Security Model](#3-security-model)
4. [Cloud Functions — Core App (6)](#4-cloud-functions--core-app)
5. [Cloud Functions — Admin APIs (8)](#5-cloud-functions--admin-apis)
6. [Admin React Frontend](#6-admin-react-frontend)
7. [Authentication Flow](#7-authentication-flow)
8. [Deploy Checklist](#8-deploy-checklist)

---

## 1. Architecture Overview

```
                    ┌──────────────────────────────┐
                    │     RAKTA BANDHAN SYSTEM      │
                    └──────────────────────────────┘
                                   │
        ┌──────────────────────────┼──────────────────────┐
        │                          │                       │
┌───────▼────────┐     ┌───────────▼──────────┐   ┌──────▼──────────┐
│  Flutter App   │     │   Firebase Auth       │   │  React Admin    │
│  (Donors +     │────►│   (OTP / Email +      │◄──│  Dashboard      │
│   Requesters)  │     │   Custom Claims)      │   │  (Hosted SPA)   │
└───────┬────────┘     └───────────┬──────────┘   └──────┬──────────┘
        │                          │                       │
        └──────────────────────────▼───────────────────────┘
                                   │
                    ┌──────────────▼──────────────┐
                    │      Cloud Firestore         │
                    │   (Real-time document DB)    │
                    │                             │
                    │  /donors        /requests   │
                    │  /hospitals     /config     │
                    │  /notifications /users      │
                    │  /donation_history          │
                    │  /admin_audit_log           │
                    └──────────────┬──────────────┘
                                   │
                    ┌──────────────▼──────────────┐
                    │      Cloud Functions         │
                    │      (Node.js — 14 total)   │
                    │                             │
                    │  Core:   6 functions         │
                    │  Admin:  8 functions         │
                    └──────┬────────────┬──────────┘
                           │            │
               ┌───────────▼──┐   ┌────▼──────────┐
               │     FCM      │   │  MSG91 SMS     │
               │  (Push Notif)│   │  (Fallback)    │
               └──────────────┘   └───────────────┘
```

### Key Design Decisions

| Decision | Choice | Rationale |
|---|---|---|
| **Admin Auth** | Email/Password + Custom Claims | No OTP needed for admins; `admin: true` claim enforced server-side |
| **Real-time UI** | Firestore `onSnapshot` subscriptions | Donors/Requests pages update without refresh |
| **Admin Actions** | HTTPS Callable Cloud Functions | Security enforced server-side; not bypassable from client |
| **Audit Trail** | Firestore + Admin SDK only | `allow write: if false` makes it tamper-proof from clients |
| **Analytics** | Cloud Function aggregation | Avoids expensive client-side full collection reads |
| **Ban Mechanism** | Firebase Auth `disabled` + Firestore flag | Blocks login at infrastructure level, not just app level |

---

## 2. Firestore Collections Schema

### `/donors/{uid}`
```
donors/{uid}
  ├── name: string
  ├── phone: string
  ├── blood_group: 'A+' | 'A-' | 'B+' | 'B-' | 'AB+' | 'AB-' | 'O+' | 'O-'
  ├── geohash: string                      ← For geo-radius queries
  ├── lat: number
  ├── lng: number
  ├── is_available: boolean
  ├── is_verified: boolean                 ← Set by admin only
  ├── is_banned: boolean                   ← Set by adminBanUser()
  ├── ban_reason: string | null
  ├── banned_at: timestamp | null
  ├── banned_by: string | null             ← Admin UID
  ├── fcm_token: string                    ← Cleared on ban
  ├── last_donation_date: timestamp | null
  ├── reactivation_scheduled_at: timestamp | null
  ├── verified_at: timestamp | null
  ├── verified_by: string | null           ← Admin UID
  ├── rejection_reason: string | null
  └── created_at: timestamp
```

### `/requests/{requestId}`
```
requests/{requestId}
  ├── requester_uid: string
  ├── hospital_id: string | null
  ├── blood_group: string
  ├── units_needed: number
  ├── urgency: 'critical' | 'urgent' | 'normal'
  ├── status: 'open' | 'matched' | 'fulfilled' | 'expired' | 'cancelled'
  ├── geohash: string
  ├── lat: number
  ├── lng: number
  ├── matched_donor_id: string | null
  ├── matched_at: timestamp | null
  ├── fulfilled_at: timestamp | null
  ├── fulfilled_by: string | null          ← Admin UID
  ├── created_at: timestamp
  └── expires_at: timestamp               ← Auto-expire after 6 hours
```

### `/hospitals/{hospitalId}`
```
hospitals/{hospitalId}
  ├── hospital_id: string                  ← Same as doc ID
  ├── name: string
  ├── address: string
  ├── city: string | null
  ├── state: string | null
  ├── lat: number | null
  ├── lng: number | null
  ├── contact_phone: string
  ├── contact_email: string | null
  ├── verified: boolean
  ├── created_by: string                   ← Admin UID
  ├── created_at: timestamp
  └── updated_at: timestamp
```

### `/donation_history/{recordId}`
```
donation_history/{recordId}
  ├── record_id: string
  ├── donor_id: string
  ├── request_id: string
  ├── hospital_id: string | null
  ├── donation_date: timestamp
  ├── verified_by: string                  ← Admin UID
  └── created_at: timestamp
```

### `/notifications/{notificationId}`
```
notifications/{notificationId}
  ├── donor_id: string
  ├── request_id: string
  ├── requester_uid: string
  ├── status: 'sent' | 'accepted' | 'declined' | 'expired'
  └── timestamp: timestamp
```

### `/admin_audit_log/{logId}`
```
admin_audit_log/{logId}
  ├── action: string                       ← e.g. 'VERIFY_DONOR', 'BAN_USER'
  ├── performed_by: string                 ← Admin UID
  ├── target_uid: string | null
  ├── target_id: string | null             ← For non-user targets (hospitals)
  ├── target_name: string | null
  ├── target_email: string | null
  ├── reason: string | null
  ├── details: object | null               ← For broadcasts, complex actions
  └── timestamp: timestamp                 ← Server-set, immutable
```

> **Tamper-proof:** `allow write: if false` — only Cloud Functions (Admin SDK) can write here.

### `/config/{docId}`
App-wide configuration. Readable by all authenticated users, writable only by admins.

---

## 3. Security Model

### Firestore Rules Matrix

| Collection | Auth Users Read | Admin Read | Write Rules |
|---|---|---|---|
| `/donors` | Limited (verified+available only) | Full | Owner: create/update (no self-verify). Admin: delete |
| `/requests` | Yes | Yes | Owner: create/cancel. Admin: any update/delete |
| `/hospitals` | Yes | Yes | Admin only |
| `/notifications` | Own records | All | Donor: accept/decline only. Functions: create |
| `/donation_history` | Own records | All | **Functions only** |
| `/admin_audit_log` | **No** | **Yes** | **Nobody (Functions only)** |
| `/config` | Yes | Yes | Admin only |
| `/users` | Own record | All | Owner (no ban flag). Admin: delete |

### Admin Custom Claim
```javascript
// Firebase Auth custom claim (set by setAdminRole Cloud Function)
{ admin: true }

// Checked in every admin Cloud Function:
if (!context.auth || !context.auth.token.admin) {
  throw new HttpsError('permission-denied', 'Admin access required.');
}

// Checked in Firestore rules:
function isAdmin() {
  return request.auth != null && request.auth.token.admin == true;
}

// Checked in React AuthContext (client):
const tokenResult = await user.getIdTokenResult(true);
const isAdmin = !!tokenResult.claims.admin;
```

---

## 4. Cloud Functions — Core App

### `onRequestCreated` — Firestore Trigger
- **Trigger:** New document written to `/requests`
- **Memory:** 256MB · **Timeout:** 60s
- **Flow:**
  1. Compute geohash neighbors for radius search (default 5km, fallback 15km)
  2. Query `/donors` for matching blood group + `is_available=true` + `is_verified=true`
  3. Rank by distance, notify top 10 donors via FCM
  4. Fall back to MSG91 SMS if donor's `last_seen` > 30 min
  5. Create `/notifications` documents with status `sent`

### `onDonorAccepts` — Firestore Trigger
- **Trigger:** `/notifications/{id}` status changes to `"accepted"`
- **Memory:** 128MB · **Timeout:** 30s
- **Flow:**
  1. Update `/requests` → `status: "matched"`, `matched_donor_id`
  2. FCM to requester: "Donor on the way!"
  3. FCM to all other notified donors: "Request fulfilled by another"

### `scheduledReactivation` — Cron (hourly)
- **Schedule:** Every hour
- **Memory:** 256MB · **Timeout:** 120s
- **Flow:** Find donors where `reactivation_scheduled_at <= now`, set `is_available = true`, send FCM

### `expireOldRequests` — Cron (every 30 min)
- **Schedule:** Every 30 minutes
- **Memory:** 128MB · **Timeout:** 60s
- **Flow:** Find open requests where `expires_at <= now`, set `status = "expired"`, notify requester

### `onDonationConfirmed` — HTTPS Callable (Admin)
- **Auth:** Admin required
- **Memory:** 256MB · **Timeout:** 30s
- **Flow:** Create `/donation_history`, set donor cooldown (90 days), mark request `fulfilled`, thank-you FCM

### `setAdminRole` — HTTPS Callable
- **Auth:** Existing admin required
- **Memory:** 128MB · **Timeout:** 30s
- **Flow:** Set `{ admin: true/false }` custom claim, write audit log

---

## 5. Cloud Functions — Admin APIs

> All admin functions are **HTTPS Callable** (not REST endpoints).  
> Called via Firebase SDK: `const fn = httpsCallable(functions, 'functionName')`  
> All enforce: `context.auth.token.admin === true`

---

### `adminGetDashboardStats`
**Purpose:** KPI aggregates for dashboard home page  
**Memory:** 256MB · **Timeout:** 60s

**Input:** `{}` (no parameters)

**Output:**
```json
{
  "totalDonors": 120,
  "verifiedDonors": 89,
  "availableDonors": 62,
  "bannedUsers": 3,
  "totalRequests": 450,
  "openRequests": 12,
  "matchedRequests": 5,
  "fulfilledRequests": 380,
  "expiredRequests": 45,
  "cancelledRequests": 8,
  "totalHospitals": 15,
  "verifiedHospitals": 12,
  "totalDonations": 380,
  "donationsThisMonth": 24,
  "fulfillmentRate": 89,
  "avgResponseTimeMinutes": 7,
  "recentRequests": [ /* last 5 requests */ ],
  "recentDonors": [ /* last 5 donors */ ]
}
```

---

### `adminVerifyDonor`
**Purpose:** Approve or reject a donor's verification  
**Side Effects:** Updates `/donors/{id}`, sends FCM to donor, writes audit log  
**Memory:** 128MB · **Timeout:** 30s

**Input:**
```json
{
  "donorId": "uid_string",
  "isVerified": true,
  "reason": "Optional rejection reason (only for false)"
}
```

**Output:**
```json
{
  "success": true,
  "donorId": "uid_string",
  "isVerified": true,
  "message": "Donor has been verified..."
}
```

**FCM sent to donor:** "✅ Your verification was approved" or "❌ Verification not approved"

---

### `adminToggleDonorAvailability`
**Purpose:** Admin override of a donor's availability status  
**Side Effects:** Updates `/donors/{id}`, writes audit log  
**Memory:** 128MB · **Timeout:** 20s

**Input:**
```json
{
  "donorId": "uid_string",
  "isAvailable": false,
  "reason": "Donor unreachable — manually deactivated"
}
```

**Output:**
```json
{
  "success": true,
  "donorId": "uid_string",
  "isAvailable": false,
  "message": "Donor availability set to unavailable by admin."
}
```

---

### `adminBanUser`
**Purpose:** Ban/unban a user — disables Firebase Auth account, clears FCM token  
**Side Effects:** `admin.auth().updateUser({ disabled: true })`, updates `/donors/{uid}`, writes audit log  
**Memory:** 128MB · **Timeout:** 30s

> ⚠️ **Cannot ban yourself.** Banned users cannot log in at the infrastructure level.

**Input:**
```json
{
  "targetUid": "uid_string",
  "isBanned": true,
  "reason": "Fake account detected"
}
```

**Output:**
```json
{
  "success": true,
  "targetUid": "uid_string",
  "isBanned": true,
  "message": "User user@email.com has been banned."
}
```

---

### `adminManageHospital`
**Purpose:** Full CRUD for hospital records  
**Memory:** 128MB · **Timeout:** 30s

**Actions:** `create` | `update` | `delete` | `toggleVerified`

**Input (create):**
```json
{
  "action": "create",
  "name": "Apollo Hospital",
  "address": "123 Main St, Pune",
  "city": "Pune",
  "state": "Maharashtra",
  "contact_phone": "+91-9876543210",
  "contact_email": "admin@apollo.com",
  "lat": 18.5204,
  "lng": 73.8567
}
```

**Input (update):**
```json
{
  "action": "update",
  "hospitalId": "doc_id",
  "contact_phone": "+91-9876543211"
}
```

**Input (toggleVerified):**
```json
{ "action": "toggleVerified", "hospitalId": "doc_id" }
```

**Input (delete):**
```json
{ "action": "delete", "hospitalId": "doc_id" }
```

---

### `adminGetAnalytics`
**Purpose:** Time-series analytics for dashboard charts  
**Memory:** 512MB · **Timeout:** 120s

**Input:**
```json
{ "period": "30d" }
```
Valid periods: `"7d"` | `"30d"` | `"90d"` | `"12m"`

**Output:**
```json
{
  "period": "30d",
  "generatedAt": "2026-08-14T07:00:00Z",
  "requestsByDay": [
    { "date": "2026-07-15", "total": 8, "fulfilled": 6, "expired": 1, "open": 1, "matched": 0 }
  ],
  "donorsByDay": [
    { "date": "2026-07-15", "total": 3, "verified": 2 }
  ],
  "donationsByMonth": [
    { "month": "2026-07", "count": 24 }
  ],
  "bloodGroupDistribution": [
    { "group": "O+", "count": 34 },
    { "group": "A+", "count": 28 }
  ],
  "fulfillmentRateByUrgency": [
    { "urgency": "critical", "total": 12, "fulfilled": 11, "rate": 91 }
  ],
  "topHospitals": [
    { "hospitalId": "abc", "name": "Apollo Hospital", "requestCount": 45 }
  ]
}
```

---

### `adminBroadcastNotification`
**Purpose:** Push notification to all/filtered verified donors  
**Side Effects:** FCM multicast (batches of 500), writes audit log  
**Memory:** 512MB · **Timeout:** 120s

**Input:**
```json
{
  "title": "🚨 Urgent: O- Blood Needed",
  "body": "Govt Hospital Pune urgently needs O- blood. Tap to respond.",
  "bloodGroup": "O-",
  "availableOnly": true,
  "type": "ADMIN_BROADCAST"
}
```
> `bloodGroup`: Optional. Omit to send to all blood groups.  
> `availableOnly`: Defaults to `true`. Set to `false` to include unavailable donors.

**Output:**
```json
{
  "success": true,
  "sent": 42,
  "failed": 2,
  "targeted": 44,
  "message": "Notification sent to 42 donors. 2 failed."
}
```

---

### `adminGetAuditLog`
**Purpose:** Paginated admin audit trail  
**Memory:** 128MB · **Timeout:** 30s

**Input:**
```json
{
  "limit": 50,
  "startAfter": "last_doc_id",
  "action": "BAN_USER",
  "performedBy": "admin_uid"
}
```
> All fields optional. Max limit: 200.

**Output:**
```json
{
  "entries": [
    {
      "id": "log_id",
      "action": "VERIFY_DONOR",
      "performed_by": "admin_uid",
      "target_uid": "donor_uid",
      "target_name": "Ravi Kumar",
      "reason": null,
      "timestamp": "2026-08-14T06:30:00Z"
    }
  ],
  "count": 50,
  "hasMore": true,
  "lastId": "cursor_doc_id"
}
```

**Complete Audit Actions Reference:**

| Action | Triggered By Function |
|---|---|
| `VERIFY_DONOR` | `adminVerifyDonor` |
| `UNVERIFY_DONOR` | `adminVerifyDonor` |
| `FORCE_DONOR_AVAILABLE` | `adminToggleDonorAvailability` |
| `FORCE_DONOR_UNAVAILABLE` | `adminToggleDonorAvailability` |
| `BAN_USER` | `adminBanUser` |
| `UNBAN_USER` | `adminBanUser` |
| `CREATE_HOSPITAL` | `adminManageHospital` |
| `UPDATE_HOSPITAL` | `adminManageHospital` |
| `DELETE_HOSPITAL` | `adminManageHospital` |
| `VERIFY_HOSPITAL` | `adminManageHospital` |
| `UNVERIFY_HOSPITAL` | `adminManageHospital` |
| `BROADCAST_NOTIFICATION` | `adminBroadcastNotification` |
| `GRANT_ADMIN` | `setAdminRole` |
| `REVOKE_ADMIN` | `setAdminRole` |

---

## 6. Admin React Frontend

### Pages & Routes

| Route | Page Component | Data Source | Live? |
|---|---|---|---|
| `/login` | `Login.tsx` | Firebase Auth | — |
| `/` | `DashboardHome.tsx` | `adminGetDashboardStats` | On-demand |
| `/donors` | `DonorsPage.tsx` | Firestore `/donors` | ✅ Real-time |
| `/requests` | `RequestsPage.tsx` | Firestore `/requests` | ✅ Real-time |
| `/hospitals` | `HospitalsPage.tsx` | Firestore `/hospitals` | ✅ Real-time |
| `/history` | `DonationHistoryPage.tsx` | Firestore `/donation_history` | ✅ Real-time |
| `/analytics` | `AnalyticsPage.tsx` | `adminGetAnalytics` | On-demand |
| `/broadcast` | `BroadcastPage.tsx` | `adminBroadcastNotification` | On-demand |
| `/audit` | `AuditLogPage.tsx` | `adminGetAuditLog` | On-demand |

### Key Source Files

| File | Purpose |
|---|---|
| `src/lib/firebase.ts` | Firebase SDK init + typed callable wrappers for all 10 admin functions |
| `src/contexts/AuthContext.tsx` | Auth state provider, admin claim verification on every session |
| `src/App.tsx` | BrowserRouter + ProtectedRoute guard |
| `src/pages/DashboardShell.tsx` | Sidebar layout with NavLink + nested Routes |
| `src/hooks/useFirebaseData.ts` | All Firestore `onSnapshot` hooks + Cloud Function call hooks |
| `src/pages/DonorsPage.tsx` | Live table with verify/ban/availability actions |
| `src/pages/RequestsPage.tsx` | Live requests with status filter pills |
| `src/pages/HospitalsPage.tsx` | Hospital grid with add form + verify/delete |
| `src/pages/AnalyticsPage.tsx` | Blood group bars, fulfillment rate, activity chart, top hospitals |
| `src/pages/BroadcastPage.tsx` | Broadcast form with blood group + availability filter |
| `src/pages/AuditLogPage.tsx` | Paginated audit trail with color-coded action badges |

---

## 7. Authentication Flow

```
Admin Login:
─────────────
1. Opens /login page (no session → ProtectedRoute redirects here)
2. Enters admin email + password
3. signInWithEmailAndPassword(auth, email, password)
4. On success → getIdTokenResult(true) to check custom claims
5. claims.admin === true?
   ├── YES → navigate('/'), AuthContext sets isAdmin = true
   └── NO  → signOut() + display "No admin privileges" error

Session Refresh:
────────────────
6. onAuthStateChanged fires on every page load
7. getIdTokenResult(true) called (force refresh = true)
8. isAdmin state updated from fresh ID token

Route Protection:
─────────────────
9. All routes under /* are wrapped in <ProtectedRoute>
10. ProtectedRoute checks { loading, currentUser, isAdmin }
    ├── loading  → show spinner
    ├── !isAdmin → <Navigate to="/login" replace />
    └── isAdmin  → render page component
```

---

## 8. Deploy Checklist

Deploy config (`firebase.json`, `.firebaserc`, rules/indexes) lives in
`app/backend/` — there's one Firebase project shared by both apps. Run
these from `app/backend/`, not here:

```bash
# Step 1: Set up secrets
firebase functions:secrets:set MSG91_API_KEY

# Step 2: Deploy Firestore rules and indexes
firebase deploy --only firestore

# Step 3: Deploy Cloud Functions (both codebases)
firebase deploy --only functions:app,functions:admin

# Step 4: Build the React admin dashboard
cd ../../admin/frontend
npm run build

# Step 5: Deploy to Firebase Hosting
cd ../../app/backend
firebase deploy --only hosting

# Step 6: Bootstrap the first admin user (one-time)
node ../../admin/backend/bootstrap-admin.js

# Step 7: Verify deployment
firebase functions:list
```

### Function Runtime Reference

| Function | Type | Memory | Timeout | Notes |
|---|---|---|---|---|
| `onRequestCreated` | Firestore Trigger | 256MB | 60s | Geo-matching + FCM + SMS |
| `onDonorAccepts` | Firestore Trigger | 128MB | 30s | Lock request + notify |
| `scheduledReactivation` | Cron (1h) | 256MB | 120s | 90-day cooldown reset |
| `expireOldRequests` | Cron (30m) | 128MB | 60s | 6-hour request expiry |
| `onDonationConfirmed` | HTTPS Callable | 256MB | 30s | Admin confirms donation |
| `setAdminRole` | HTTPS Callable | 128MB | 30s | Grant/revoke admin claim |
| `adminGetDashboardStats` | HTTPS Callable | 256MB | 60s | KPI aggregates |
| `adminVerifyDonor` | HTTPS Callable | 128MB | 30s | Verify + FCM + audit |
| `adminToggleDonorAvailability` | HTTPS Callable | 128MB | 20s | Force toggle + audit |
| `adminBanUser` | HTTPS Callable | 128MB | 30s | Auth disable + audit |
| `adminManageHospital` | HTTPS Callable | 128MB | 30s | CRUD + audit |
| `adminGetAnalytics` | HTTPS Callable | 512MB | 120s | Time-series aggregation |
| `adminBroadcastNotification` | HTTPS Callable | 512MB | 120s | FCM multicast batches |
| `adminGetAuditLog` | HTTPS Callable | 128MB | 30s | Paginated audit trail |
