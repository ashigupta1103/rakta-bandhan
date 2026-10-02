/**
 * useFirebaseData — Firestore hooks + admin actions for the dashboard.
 *
 * Everything here talks to Firestore directly. This project runs on the
 * Firebase Spark (free) plan — no Cloud Functions are deployed — so there
 * is no adminGetDashboardStats/adminVerifyDonor/etc. to call. Stats are
 * computed client-side from live collection data, and admin actions are
 * plain Firestore writes gated by firestore.rules' isAdmin() check (see
 * backend/BACKEND_REFERENCE.md for the full architecture note).
 */

import { useState, useEffect, useMemo, useCallback } from 'react';
import {
  collection,
  onSnapshot,
  query,
  orderBy,
  limit,
  where,
  doc,
  addDoc,
  updateDoc,
  deleteDoc,
  setDoc,
  writeBatch,
  deleteField,
  getCountFromServer,
  getDoc,
  serverTimestamp,
  type DocumentData,
} from 'firebase/firestore';
import { db, auth } from '../lib/firebase';
import { deleteMedia, deleteIdProof } from '../lib/edge';

// ─── Types ────────────────────────────────────────────────────────────────────

export interface Donor extends DocumentData {
  id: string;
  name: string;
  phone: string;
  blood_group: string;
  is_verified: boolean;
  is_available: boolean;
  is_banned?: boolean;
  geohash: string;
  lat: number;
  lng: number;
  last_donation_date?: { toDate: () => Date } | null;
  reactivation_scheduled_at?: { toDate: () => Date } | null;
  created_at?: { toDate: () => Date };
}

export interface BloodRequest extends DocumentData {
  id: string;
  requester_uid: string;
  hospital_id?: string;
  location_label?: string;
  blood_group: string;
  units_needed: number;
  urgency: 'critical' | 'urgent' | 'normal';
  status: 'open' | 'matched' | 'fulfilled' | 'expired' | 'cancelled';
  lat: number;
  lng: number;
  matched_donor_id?: string;
  matched_donor_name?: string;
  matched_at?: { toDate: () => Date };
  fulfilled_at?: { toDate: () => Date };
  created_at?: { toDate: () => Date };
  expires_at?: { toDate: () => Date };
}

export interface Hospital extends DocumentData {
  id: string;
  name: string;
  address: string;
  city?: string;
  state?: string;
  lat?: number;
  lng?: number;
  contact_phone: string;
  contact_email?: string;
  verified: boolean;
  created_at?: { toDate: () => Date };
}

export interface AuditEntry extends DocumentData {
  id: string;
  action: string;
  performed_by?: string;
  target_uid?: string;
  target_name?: string;
  reason?: string;
  at?: { toDate: () => Date };
}

/** Triage state on both inbox collections. A doc with no `status` is new. */
export type InboxStatus = 'new' | 'in_progress' | 'resolved';

export const INBOX_STATUSES: InboxStatus[] = ['new', 'in_progress', 'resolved'];

export const INBOX_STATUS_LABELS: Record<InboxStatus, string> = {
  new: 'New',
  in_progress: 'In progress',
  resolved: 'Resolved',
};

export interface IssueReport extends DocumentData {
  id: string;
  reporter_uid: string;
  reason: string;
  details?: string;
  status?: InboxStatus;
  admin_note?: string;
  created_at?: { toDate: () => Date };
}

export interface PartnershipInquiry extends DocumentData {
  id: string;
  requester_uid: string;
  org_name: string;
  contact_name: string;
  work_email: string;
  interest: string;
  message?: string;
  status?: InboxStatus;
  admin_note?: string;
  created_at?: { toDate: () => Date };
}

/** Chat/call abuse report (ChatService.report) — admin can update the
 * triage status but never delete one; the rules keep it a permanent
 * record regardless of outcome. */
export interface AbuseReport extends DocumentData {
  id: string;
  reporter_uid: string;
  reported_uid: string;
  request_id: string;
  /** Set when a community post (not a chat) was reported. */
  story_id?: string;
  reason: string;
  details?: string;
  status?: InboxStatus;
  admin_note?: string;
  created_at?: { toDate: () => Date };
}

export interface CommunityStory extends DocumentData {
  id: string;
  author_uid: string;
  author_name?: string;
  topic?: string;
  body: string;
  is_hidden?: boolean;
  created_at?: { toDate: () => Date };
}

export interface Announcement extends DocumentData {
  id: string;
  title: string;
  body: string;
  created_at?: { toDate: () => Date };
}

export interface Testimonial extends DocumentData {
  id: string;
  quote: string;
  name: string;
  role?: string;
  created_at?: { toDate: () => Date };
}

export interface DashboardStats {
  totalDonors: number;
  verifiedDonors: number;
  availableDonors: number;
  bannedUsers: number;
  totalRequests: number;
  openRequests: number;
  matchedRequests: number;
  fulfilledRequests: number;
  expiredRequests: number;
  cancelledRequests: number;
  totalHospitals: number;
  verifiedHospitals: number;
  totalDonations: number;
  donationsThisMonth: number;
  fulfillmentRate: number;
  avgResponseTimeMinutes: number;
  recentRequests: BloodRequest[];
  recentDonors: Donor[];
}

// ─── Real-time collection hooks ───────────────────────────────────────────────

/** Live donor list (all donors, newest first) */
export function useDonors(bloodGroupFilter?: string, verifiedOnly?: boolean) {
  const [donors, setDonors] = useState<Donor[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const q = query(collection(db, 'donors'), orderBy('created_at', 'desc'), limit(200));

    const unsub = onSnapshot(q, (snapshot) => {
      let docs = snapshot.docs.map((d) => ({ id: d.id, ...d.data() } as Donor));
      if (bloodGroupFilter) docs = docs.filter((d) => d.blood_group === bloodGroupFilter);
      if (verifiedOnly) docs = docs.filter((d) => d.is_verified);
      setDonors(docs);
      setLoading(false);
    });

    return () => unsub();
  }, [bloodGroupFilter, verifiedOnly]);

  return { donors, loading };
}

/** Live blood requests (newest first) */
export function useRequests(statusFilter?: string) {
  const [requests, setRequests] = useState<BloodRequest[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const q = query(collection(db, 'requests'), orderBy('created_at', 'desc'), limit(200));

    const unsub = onSnapshot(q, (snapshot) => {
      let docs = snapshot.docs.map((d) => ({ id: d.id, ...d.data() } as BloodRequest));
      if (statusFilter && statusFilter !== 'all') docs = docs.filter((r) => r.status === statusFilter);
      setRequests(docs);
      setLoading(false);
    });

    return () => unsub();
  }, [statusFilter]);

  return { requests, loading };
}

/** Live hospital list */
export function useHospitals() {
  const [hospitals, setHospitals] = useState<Hospital[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const q = query(collection(db, 'hospitals'), orderBy('created_at', 'desc'));
    const unsub = onSnapshot(q, (snapshot) => {
      setHospitals(snapshot.docs.map((d) => ({ id: d.id, ...d.data() } as Hospital)));
      setLoading(false);
    });
    return () => unsub();
  }, []);

  return { hospitals, loading };
}

/**
 * Live "donation history" — derived from fulfilled requests rather than
 * the dormant /donation_history collection (that was written by the
 * Blaze-only onDonationConfirmed.js). Donors self-report on the app, so
 * a fulfilled request *is* the donation record on Spark.
 */
export function useDonationHistory() {
  const { requests, loading } = useRequests('fulfilled');
  const donations = useMemo(
    () =>
      [...requests].sort((a, b) => {
        const at = a.fulfilled_at?.toDate?.().getTime() ?? 0;
        const bt = b.fulfilled_at?.toDate?.().getTime() ?? 0;
        return bt - at;
      }),
    [requests]
  );
  return { donations, loading };
}

/**
 * Live admin audit log (most recent 100) — `audit_log`, the same
 * collection the Flutter app's admin console writes to (backend.dart's
 * _logAdminAction). Ordered by `at`, the one timestamp field every
 * entry from either client always sets.
 */
export function useAuditLog() {
  const [entries, setEntries] = useState<AuditEntry[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const q = query(collection(db, 'audit_log'), orderBy('at', 'desc'), limit(100));
    const unsub = onSnapshot(q, (snapshot) => {
      setEntries(snapshot.docs.map((d) => ({ id: d.id, ...d.data() } as AuditEntry)));
      setLoading(false);
    });
    return () => unsub();
  }, []);

  return { entries, loading };
}

/**
 * One generic live-collection hook for the five newest-first collections the
 * Inbox and Content pages read. They differ only in name and shape, so a
 * hook each would be five copies of the same six lines.
 */
function useCollection<T>(name: string, max = 100) {
  const [items, setItems] = useState<T[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const q = query(collection(db, name), orderBy('created_at', 'desc'), limit(max));
    const unsub = onSnapshot(
      q,
      (snapshot) => {
        setItems(snapshot.docs.map((d) => ({ id: d.id, ...d.data() } as T)));
        setLoading(false);
      },
      () => setLoading(false)
    );
    return () => unsub();
  }, [name, max]);

  return { items, loading };
}

/** "Report an issue" submissions (Help & support in the app). */
export function useIssueReports() {
  const { items, loading } = useCollection<IssueReport>('issue_reports');
  return { reports: items, loading };
}

/** "Start a conversation" submissions (Corporate partnerships in the app). */
export function usePartnershipInquiries() {
  const { items, loading } = useCollection<PartnershipInquiry>('partnership_inquiries');
  return { inquiries: items, loading };
}

/** Chat/call abuse reports (ChatService.report) — the one inbox the
 * chat/calls branch didn't wire into either admin console. */
export function useAbuseReports() {
  const { items, loading } = useCollection<AbuseReport>('reports');
  return { reports: items, loading };
}

/** Member-posted Community stories — admin moderates (hide or delete). */
export function useCommunityStories() {
  const { items, loading } = useCollection<CommunityStory>('community_stories');
  return { stories: items, loading };
}

/** Community → What's New. Admin-authored; no user-write path exists. */
export function useAnnouncements() {
  const { items, loading } = useCollection<Announcement>('announcements');
  return { announcements: items, loading };
}

/** More → Testimonials. Curated quotes, admin-write-only per rules. */
export function useTestimonials() {
  const { items, loading } = useCollection<Testimonial>('testimonials');
  return { testimonials: items, loading };
}

function currentMonthKey() {
  const now = new Date();
  return `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}`;
}

/**
 * The `public_stats/impact` counter behind Community → Impact. Reads 0 for a
 * stale month rather than last month's figure — same rule the Flutter client
 * applies in Backend.impactThisMonthStream.
 */
export function useImpactCounter() {
  const [count, setCount] = useState<number | null>(null);

  useEffect(() => {
    const unsub = onSnapshot(doc(db, 'public_stats', 'impact'), (snap) => {
      const data = snap.data();
      if (!data || data.month_key !== currentMonthKey()) {
        setCount(0);
        return;
      }
      setCount(Number(data.donations_this_month ?? 0));
    });
    return () => unsub();
  }, []);

  return { count };
}

// ─── Client-computed dashboard stats (no Cloud Function) ─────────────────────

export function useDashboardStats() {
  const { donors, loading: donorsLoading } = useDonors();
  const { requests, loading: requestsLoading } = useRequests();
  const { hospitals, loading: hospitalsLoading } = useHospitals();
  const loading = donorsLoading || requestsLoading || hospitalsLoading;

  const stats = useMemo<DashboardStats>(() => {
    const now = new Date();
    const startOfMonth = new Date(now.getFullYear(), now.getMonth(), 1);

    const fulfilled = requests.filter((r) => r.status === 'fulfilled');
    const withResponseTime = requests.filter((r) => r.matched_at && r.created_at);
    const avgResponseTimeMinutes = withResponseTime.length
      ? Math.round(
          withResponseTime.reduce((sum, r) => {
            const created = r.created_at!.toDate().getTime();
            const matched = r.matched_at!.toDate().getTime();
            return sum + (matched - created) / 60000;
          }, 0) / withResponseTime.length
        )
      : 0;

    const totalRequests = requests.length;
    const fulfillmentRate = totalRequests
      ? Math.round((fulfilled.length / totalRequests) * 100)
      : 0;

    return {
      totalDonors: donors.length,
      verifiedDonors: donors.filter((d) => d.is_verified).length,
      availableDonors: donors.filter((d) => d.is_available && !d.is_banned).length,
      bannedUsers: donors.filter((d) => d.is_banned).length,
      totalRequests,
      openRequests: requests.filter((r) => r.status === 'open').length,
      matchedRequests: requests.filter((r) => r.status === 'matched').length,
      fulfilledRequests: fulfilled.length,
      expiredRequests: requests.filter((r) => r.status === 'expired').length,
      cancelledRequests: requests.filter((r) => r.status === 'cancelled').length,
      totalHospitals: hospitals.length,
      verifiedHospitals: hospitals.filter((h) => h.verified).length,
      totalDonations: fulfilled.length,
      donationsThisMonth: fulfilled.filter(
        (r) => (r.fulfilled_at?.toDate().getTime() ?? 0) >= startOfMonth.getTime()
      ).length,
      fulfillmentRate,
      avgResponseTimeMinutes,
      recentRequests: requests.slice(0, 6),
      recentDonors: donors.slice(0, 6),
    };
  }, [donors, requests, hospitals]);

  return { stats, loading, error: null as string | null };
}

// ─── Client-computed analytics (no Cloud Function) ────────────────────────────

const PERIOD_DAYS: Record<'7d' | '30d' | '90d' | '12m', number> = {
  '7d': 7,
  '30d': 30,
  '90d': 90,
  '12m': 365,
};

export function useAnalytics(period: '7d' | '30d' | '90d' | '12m' = '30d') {
  const { donors, loading: donorsLoading } = useDonors();
  const { requests, loading: requestsLoading } = useRequests();
  const { hospitals } = useHospitals();
  const loading = donorsLoading || requestsLoading;

  const data = useMemo(() => {
    const cutoff = new Date();
    cutoff.setDate(cutoff.getDate() - PERIOD_DAYS[period]);
    const inPeriod = requests.filter((r) => (r.created_at?.toDate().getTime() ?? 0) >= cutoff.getTime());

    const bloodGroupDistribution = Object.entries(
      donors.reduce<Record<string, number>>((acc, d) => {
        acc[d.blood_group] = (acc[d.blood_group] || 0) + 1;
        return acc;
      }, {})
    ).map(([group, count]) => ({ group, count }));

    const urgencyGroups: Record<string, { total: number; fulfilled: number }> = {};
    for (const r of inPeriod) {
      const key = r.urgency || 'normal';
      urgencyGroups[key] ??= { total: 0, fulfilled: 0 };
      urgencyGroups[key].total++;
      if (r.status === 'fulfilled') urgencyGroups[key].fulfilled++;
    }
    const fulfillmentRateByUrgency = Object.entries(urgencyGroups).map(([urgency, v]) => ({
      urgency,
      total: v.total,
      fulfilled: v.fulfilled,
      rate: v.total ? Math.round((v.fulfilled / v.total) * 100) : 0,
    }));

    const dayGroups: Record<string, { total: number; fulfilled: number }> = {};
    for (const r of inPeriod) {
      const d = r.created_at?.toDate();
      if (!d) continue;
      const key = d.toISOString().slice(0, 10);
      dayGroups[key] ??= { total: 0, fulfilled: 0 };
      dayGroups[key].total++;
      if (r.status === 'fulfilled') dayGroups[key].fulfilled++;
    }
    const requestsByDay = Object.entries(dayGroups)
      .sort(([a], [b]) => a.localeCompare(b))
      .map(([date, v]) => ({ date, ...v }));

    const hospitalNameById = new Map(hospitals.map((h) => [h.id, h.name]));
    const hospitalGroups: Record<string, number> = {};
    for (const r of inPeriod) {
      if (!r.hospital_id) continue;
      hospitalGroups[r.hospital_id] = (hospitalGroups[r.hospital_id] || 0) + 1;
    }
    const topHospitals = Object.entries(hospitalGroups)
      .map(([id, requestCount]) => ({ name: hospitalNameById.get(id) || id, requestCount }))
      .sort((a, b) => b.requestCount - a.requestCount)
      .slice(0, 8);

    return {
      generatedAt: new Date().toISOString(),
      bloodGroupDistribution,
      fulfillmentRateByUrgency,
      requestsByDay,
      topHospitals,
    };
  }, [donors, requests, hospitals, period]);

  return { data, loading, error: null as string | null };
}

// ─── Admin actions (direct Firestore writes, audit-logged) ───────────────────

/**
 * Writes both the Flutter admin console's canonical fields (actor_uid,
 * action, target, at) and this dashboard's richer display fields
 * (performed_by, target_uid, target_name, reason, timestamp) into the
 * SAME `audit_log` doc — either client can read the collection and get
 * a sensible result, since Firestore doesn't enforce a fixed schema.
 */
async function logAudit(action: string, target: { uid?: string; name?: string }, reason?: string) {
  const performedBy = auth.currentUser?.email || auth.currentUser?.uid || 'admin';
  const targetLabel = [target.name, target.uid].filter(Boolean).join(' — ') || null;
  await addDoc(collection(db, 'audit_log'), {
    actor_uid: auth.currentUser?.uid || 'admin',
    action,
    target: targetLabel,
    at: serverTimestamp(),
    performed_by: performedBy,
    target_uid: target.uid || null,
    target_name: target.name || null,
    reason: reason || null,
    timestamp: serverTimestamp(),
  });
}

export function useAdminActions() {
  const [actionLoading, setActionLoading] = useState(false);
  const [actionError, setActionError] = useState<string | null>(null);

  const run = useCallback(async <T,>(fn: () => Promise<T>): Promise<T> => {
    setActionLoading(true);
    setActionError(null);
    try {
      return await fn();
    } catch (e: unknown) {
      const msg = e instanceof Error ? e.message : 'Action failed';
      setActionError(msg);
      throw e;
    } finally {
      setActionLoading(false);
    }
  }, []);

  const verifyDonor = (donorId: string, isVerified: boolean, donorName?: string) =>
    run(async () => {
      const batch = writeBatch(db);
      if (isVerified) {
        await deleteIdProof(donorId);
        // Checked IDs aren't kept — same rule as the app's adminVerifyDonor.
        batch.delete(doc(db, 'donors', donorId, 'private', 'id_proof'));
        batch.update(doc(db, 'donors', donorId), {
          is_verified: true,
          has_id_proof: false,
          id_proof_checked_at: serverTimestamp(),
          id_proof_base64: deleteField(),
          id_proof_content_type: deleteField(),
        });
      } else {
        batch.update(doc(db, 'donors', donorId), { is_verified: false });
      }
      batch.update(doc(db, 'donors_public', donorId), {
        is_verified: isVerified,
        updated_at: serverTimestamp(),
      });
      await batch.commit();
      await logAudit(isVerified ? 'VERIFY_DONOR' : 'UNVERIFY_DONOR', { uid: donorId, name: donorName });
    });

  const toggleAvailability = (donorId: string, isAvailable: boolean, donorName?: string) =>
    run(async () => {
      const batch = writeBatch(db);
      batch.update(doc(db, 'donors', donorId), { is_available: isAvailable });
      batch.update(doc(db, 'donors_public', donorId), {
        is_available: isAvailable,
        updated_at: serverTimestamp(),
      });
      await batch.commit();
      await logAudit(isAvailable ? 'ACTIVATE_DONOR' : 'DEACTIVATE_DONOR', { uid: donorId, name: donorName });
    });

  const banUser = (donorId: string, isBanned: boolean, donorName?: string, reason?: string) =>
    run(async () => {
      const batch = writeBatch(db);
      batch.update(doc(db, 'donors', donorId), {
        is_banned: isBanned,
        ...(isBanned ? { is_available: false } : {}),
      });
      batch.update(doc(db, 'donors_public', donorId), {
        ...(isBanned ? { is_available: false } : {}),
        updated_at: serverTimestamp(),
      });
      await batch.commit();
      await logAudit(isBanned ? 'BAN_USER' : 'UNBAN_USER', { uid: donorId, name: donorName }, reason);
    });

  /**
   * Removes a donor's Firestore profile (`donors` + `donors_public`). The
   * underlying Firebase Auth account is untouched — deleting or disabling
   * another user's Auth account needs the Admin SDK, which is Blaze-only.
   * `banUser` (is_banned) is the real access-lock on Spark; use this when
   * the record itself, not just access, needs to go (spam, duplicates,
   * a takedown request).
   */
  const deleteDonor = (donorId: string, name?: string) =>
    run(async () => {
      await deleteIdProof(donorId);
      const username = (await getDoc(doc(db, 'donors', donorId))).data()?.username;
      const batch = writeBatch(db);
      if (typeof username === 'string' && (await getDoc(doc(db, 'usernames', username))).data()?.uid === donorId) batch.delete(doc(db, 'usernames', username));
      batch.delete(doc(db, 'donors', donorId, 'private', 'id_proof'));
      batch.delete(doc(db, 'donors_public', donorId));
      batch.delete(doc(db, 'donors', donorId));
      await batch.commit();
      await logAudit('DELETE_DONOR', { uid: donorId, name });
    });

  /** Removes a request outright — spam, duplicate or test postings. */
  const deleteRequest = (requestId: string) =>
    run(async () => {
      await deleteDoc(doc(db, 'requests', requestId));
      await logAudit('DELETE_REQUEST', { uid: requestId });
    });

  const createHospital = (fields: Record<string, unknown>) =>
    run(async () => {
      const ref = await addDoc(collection(db, 'hospitals'), {
        ...fields,
        verified: false,
        created_at: serverTimestamp(),
      });
      await logAudit('CREATE_HOSPITAL', { uid: ref.id, name: fields.name as string });
    });

  const toggleHospitalVerified = (hospitalId: string, verified: boolean, name?: string) =>
    run(async () => {
      await updateDoc(doc(db, 'hospitals', hospitalId), { verified });
      await logAudit(verified ? 'VERIFY_HOSPITAL' : 'UNVERIFY_HOSPITAL', { uid: hospitalId, name });
    });

  const deleteHospital = (hospitalId: string, name?: string) =>
    run(async () => {
      await deleteDoc(doc(db, 'hospitals', hospitalId));
      await logAudit('DELETE_HOSPITAL', { uid: hospitalId, name });
    });

  /**
   * Writes `broadcasts/{id}`; the onBroadcast Cloud Function delivers it
   * to the FCM topic every signed-in phone subscribes to ("all", or the
   * blood group's topic) and stamps status back onto the doc. The count
   * shown is how many donors match (count() aggregation, ~1 read per
   * 1,000 donors). Topics can't filter by availability, so
   * `availableOnly` narrows the count only.
   */
  const broadcastNotification = (params: {
    title: string;
    body: string;
    bloodGroup?: string;
    availableOnly?: boolean;
  }) =>
    run(async () => {
      let q = query(collection(db, 'donors_public'));
      if (params.bloodGroup) q = query(q, where('blood_group', '==', params.bloodGroup));
      if (params.availableOnly) q = query(q, where('is_available', '==', true));
      // count() aggregation: ~1 read per 1,000 donors instead of downloading
      // every matching donor document just to count them.
      const targeted = (await getCountFromServer(q)).data().count;

      const ref = await addDoc(collection(db, 'broadcasts'), {
        title: params.title.trim().slice(0, 80),
        body: params.body.trim().slice(0, 300),
        blood_group: params.bloodGroup ?? null,
        created_by: auth.currentUser?.uid ?? null,
        created_at: serverTimestamp(),
        status: 'queued',
      });
      await logAudit('BROADCAST_NOTIFICATION', { uid: ref.id, name: params.title }, `${targeted} donor(s) matched`);

      return {
        sent: 0,
        failed: 0,
        targeted,
        message: `Queued for ${targeted} matching donor(s). Phones receive it within a minute.`,
      };
    });

  // ── Inbox triage (issue_reports / partnership_inquiries) ────────────────
  //
  // Both collections are create-only for the submitter and admin-updatable
  // per firestore.rules, so triage is a plain field write. There is no reply
  // channel — `admin_note` is internal, and the submitter never reads it.

  const setIssueStatus = (id: string, status: InboxStatus, note?: string) =>
    run(async () => {
      await updateDoc(doc(db, 'issue_reports', id), {
        status,
        ...(note === undefined ? {} : { admin_note: note.trim() }),
        handled_by: auth.currentUser?.uid || null,
        handled_at: serverTimestamp(),
      });
      await logAudit(`issue_${status}`, { uid: id });
    });

  const deleteIssueReport = (id: string) =>
    run(async () => {
      await deleteDoc(doc(db, 'issue_reports', id));
      await logAudit('delete_issue_report', { uid: id });
    });

  const setInquiryStatus = (id: string, status: InboxStatus, note?: string) =>
    run(async () => {
      await updateDoc(doc(db, 'partnership_inquiries', id), {
        status,
        ...(note === undefined ? {} : { admin_note: note.trim() }),
        handled_by: auth.currentUser?.uid || null,
        handled_at: serverTimestamp(),
      });
      await logAudit(`inquiry_${status}`, { uid: id });
    });

  const deleteInquiry = (id: string) =>
    run(async () => {
      await deleteDoc(doc(db, 'partnership_inquiries', id));
      await logAudit('delete_partnership_inquiry', { uid: id });
    });

  /**
   * Chat/call abuse reports (ChatService.report). Same triage shape, but
   * firestore.rules gives admins `update` only, never `delete` — a report
   * stays on record regardless of outcome, so there is no delete action.
   */
  const setReportStatus = (id: string, status: InboxStatus, note?: string) =>
    run(async () => {
      await updateDoc(doc(db, 'reports', id), {
        status,
        ...(note === undefined ? {} : { admin_note: note.trim() }),
        handled_by: auth.currentUser?.uid || null,
        handled_at: serverTimestamp(),
      });
      await logAudit(`report_${status}`, { uid: id });
    });

  // ── App content (announcements, testimonials, impact, story moderation) ──

  const saveAnnouncement = (fields: { id?: string; title: string; body: string }) =>
    run(async () => {
      const data = {
        title: fields.title.trim(),
        body: fields.body.trim(),
        updated_at: serverTimestamp(),
        author_uid: auth.currentUser?.uid || null,
      };
      if (fields.id) {
        await updateDoc(doc(db, 'announcements', fields.id), data);
        await logAudit('edit_announcement', { uid: fields.id, name: data.title });
      } else {
        // created_at is set on create only, so an edit doesn't jump the post
        // back to the top of the feed.
        const ref = await addDoc(collection(db, 'announcements'), { ...data, created_at: serverTimestamp() });
        await logAudit('publish_announcement', { uid: ref.id, name: data.title });
      }
    });

  const deleteAnnouncement = (id: string, title?: string) =>
    run(async () => {
      await deleteDoc(doc(db, 'announcements', id));
      await logAudit('delete_announcement', { uid: id, name: title });
    });

  const saveTestimonial = (fields: { id?: string; quote: string; name: string; role: string }) =>
    run(async () => {
      const data = {
        quote: fields.quote.trim(),
        name: fields.name.trim(),
        role: fields.role.trim(),
        updated_at: serverTimestamp(),
        author_uid: auth.currentUser?.uid || null,
      };
      if (fields.id) {
        await updateDoc(doc(db, 'testimonials', fields.id), data);
        await logAudit('edit_testimonial', { uid: fields.id, name: data.name });
      } else {
        const ref = await addDoc(collection(db, 'testimonials'), { ...data, created_at: serverTimestamp() });
        await logAudit('publish_testimonial', { uid: ref.id, name: data.name });
      }
    });

  const deleteTestimonial = (id: string, name?: string) =>
    run(async () => {
      await deleteDoc(doc(db, 'testimonials', id));
      await logAudit('delete_testimonial', { uid: id, name });
    });

  /**
   * Overrides the Community Impact figure for the current month. The
   * +1-per-write cap in the rules applies to donors, not admins — this is
   * the correction path for a miscount or an offline-confirmed donation.
   */
  const setImpactCount = (count: number) =>
    run(async () => {
      await setDoc(doc(db, 'public_stats', 'impact'), {
        month_key: currentMonthKey(),
        donations_this_month: count,
        updated_at: serverTimestamp(),
        set_by_admin: auth.currentUser?.uid || null,
      });
      await logAudit('set_impact_count', { name: String(count) });
    });

  /** Reversible moderation — the Community feed filters `is_hidden` out. */
  const setStoryHidden = (id: string, hidden: boolean, author?: string) =>
    run(async () => {
      await updateDoc(doc(db, 'community_stories', id), {
        is_hidden: hidden,
        moderated_by: auth.currentUser?.uid || null,
        moderated_at: serverTimestamp(),
      });
      await logAudit(hidden ? 'hide_story' : 'unhide_story', { uid: id, name: author });
    });

  const deleteStory = (id: string, author?: string) =>
    run(async () => {
      const ref = doc(db, 'community_stories', id);
      const path = (await getDoc(ref)).data()?.image_path;
      if (typeof path === 'string') await deleteMedia(path);
      await deleteDoc(ref);
      await logAudit('remove_story', { uid: id, name: author });
    });

  return {
    actionLoading,
    actionError,
    verifyDonor,
    toggleAvailability,
    banUser,
    deleteDonor,
    deleteRequest,
    createHospital,
    toggleHospitalVerified,
    deleteHospital,
    broadcastNotification,
    setIssueStatus,
    deleteIssueReport,
    setInquiryStatus,
    deleteInquiry,
    setReportStatus,
    saveAnnouncement,
    deleteAnnouncement,
    saveTestimonial,
    deleteTestimonial,
    setImpactCount,
    setStoryHidden,
    deleteStory,
  };
}
