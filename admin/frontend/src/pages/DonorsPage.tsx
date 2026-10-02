/**
 * DonorsPage — Live donor list with verify, availability, and ban actions.
 * Writes go straight to Firestore (donors + donors_public dual-write) —
 * see hooks/useFirebaseData.ts for why (no admin* Cloud Functions on Spark).
 */

import { useEffect, useState } from 'react';
import { useDonors, useAdminActions, type Donor } from '../hooks/useFirebaseData';
import { CheckCircle, AlertTriangle, Search, Filter, Trash2 } from 'lucide-react';
import { Card } from '@/components/ui/card';
import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import { Table, TableHeader, TableBody, TableRow, TableHead, TableCell } from '@/components/ui/table';
import { fetchIdProof } from '../lib/edge';

const BLOOD_GROUPS = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'];

/** The same five checks as the app's admin verification checklist. */
const VERIFY_CHECKLIST = [
  'Before verifying, confirm you have:',
  '1. Seen a clear, readable ID photo (Aadhaar, PAN, DL, voter ID or passport)',
  '2. Matched the name on the ID with the profile',
  '3. Checked the donor is 18 or older',
  '4. Called or WhatsApped the number and confirmed they registered',
  '5. Confirmed the blood group with the donor',
  '',
  'Verifying deletes the ID photo; only the date it was checked is kept.',
].join('\n');

function DonorRow({ donor, onVerify, onToggle, onBan, onDelete, busy }: {
  donor: Donor;
  onVerify: (id: string, v: boolean, name: string) => void;
  onToggle: (id: string, v: boolean, name: string) => void;
  onBan: (id: string, v: boolean, name: string) => void;
  onDelete: (id: string, name: string) => void;
  busy: boolean;
}) {
  const [proof, setProof] = useState<string | null>(null);
  const [proofError, setProofError] = useState('');
  const [proofLoading, setProofLoading] = useState(false);
  return (
    <TableRow>
      <TableCell>
        <div className="flex items-center gap-2">
          <div className="w-7 h-7 rounded-full bg-muted flex items-center justify-center text-xs font-bold text-muted-foreground flex-shrink-0">
            {donor.name?.[0]?.toUpperCase() || '?'}
          </div>
          <div>
            <p className="text-sm font-medium">{donor.name}</p>
            {donor.username && <p className="text-xs text-muted-foreground">@{donor.username}</p>}
            <p className="text-xs text-muted-foreground">{donor.phone}</p>
          </div>
        </div>
      </TableCell>
      <TableCell>
        <Badge variant="destructive">{donor.blood_group}</Badge>
      </TableCell>
      <TableCell>
        {donor.is_verified
          ? <span className="inline-flex items-center gap-1 text-xs text-emerald-600"><CheckCircle className="w-3 h-3" /> Verified</span>
          : <span className="inline-flex items-center gap-1 text-xs text-amber-600"><AlertTriangle className="w-3 h-3" /> Pending</span>
        }
      </TableCell>
      <TableCell>
        {donor.is_available
          ? <span className="text-xs text-emerald-600">Available</span>
          : <span className="text-xs text-muted-foreground">Unavailable</span>
        }
      </TableCell>
      <TableCell>
        {donor.is_banned
          ? <Badge variant="destructive">Banned</Badge>
          : <Badge variant="secondary">Active</Badge>
        }
      </TableCell>
      <TableCell>
        <div className="flex items-center gap-1.5 flex-wrap">
          {(donor.has_id_proof || donor.id_proof_base64) && <Button size="sm" variant="secondary" disabled={proofLoading} onClick={async () => {
            if (proof) { setProof(null); return; }
            setProofLoading(true);
            setProofError('');
            try {
              const image = await fetchIdProof(donor.id);
              setProof(image);
              if (!image) setProofError('No ID photo on file.');
            } catch (error) {
              setProofError(error instanceof Error ? error.message : 'Could not load the ID photo.');
            } finally { setProofLoading(false); }
          }}>{proof ? 'Hide ID photo' : 'View ID photo'}</Button>}
          {proof && <img src={proof} alt="Submitted ID document" className="max-w-64 max-h-64 object-contain" />}
          {proofError && <span className="text-xs text-destructive">{proofError}</span>}
          <Button size="sm" variant="secondary" disabled={busy} onClick={() => {
            if (!donor.is_verified && !window.confirm(VERIFY_CHECKLIST)) return;
            onVerify(donor.id, !donor.is_verified, donor.name);
          }}>
            {donor.is_verified ? 'Unverify' : 'Verify'}
          </Button>
          <Button size="sm" variant="secondary" disabled={busy} onClick={() => onToggle(donor.id, !donor.is_available, donor.name)}>
            {donor.is_available ? 'Deactivate' : 'Activate'}
          </Button>
          <Button
            size="sm"
            variant={donor.is_banned ? 'secondary' : 'destructive'}
            disabled={busy}
            onClick={() => onBan(donor.id, !donor.is_banned, donor.name)}
          >
            {donor.is_banned ? 'Unban' : 'Ban'}
          </Button>
          <Button
            size="sm"
            variant="ghost"
            className="text-red-600"
            disabled={busy}
            title="Delete donor profile (sign-in removal requires the deployed backend)"
            onClick={() => {
              if (confirm(`Delete ${donor.name}'s profile? Once the backend is deployed, this also removes their sign-in account and ID proof.`)) {
                onDelete(donor.id, donor.name);
              }
            }}
          >
            <Trash2 className="w-3.5 h-3.5" />
          </Button>
        </div>
      </TableCell>
    </TableRow>
  );
}

export default function DonorsPage() {
  const [bloodGroupFilter, setBloodGroupFilter] = useState('');
  const [search, setSearch] = useState('');
  const [queryText, setQueryText] = useState('');
  const [pending, setPending] = useState(false);
  useEffect(() => { const timer = setTimeout(() => setQueryText(search), 400); return () => clearTimeout(timer); }, [search]);
  const { donors, loading, loadingMore, hasMore, loadMore, total, error } = useDonors(bloodGroupFilter || undefined, undefined, queryText, pending);
  const { actionLoading, actionError, verifyDonor, toggleAvailability, banUser, deleteDonor } = useAdminActions();

  const filtered = donors;

  return (
    <div className="p-6 space-y-5">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-xl font-semibold">Donors</h1>
          <p className="text-sm text-muted-foreground mt-0.5">
            {total === null ? '…' : `${total} matching donors`}
          </p>
        </div>
      </div>

      {actionError && (
        <div className="bg-destructive/10 border border-destructive/30 rounded-lg px-4 py-3 text-destructive text-sm">
          {actionError}
        </div>
      )}
      {error && <p className="text-sm text-destructive">{error}</p>}

      <div className="flex items-center gap-3 flex-wrap">
        <div className="relative">
          <Search className="w-4 h-4 absolute left-3 top-1/2 -translate-y-1/2 text-muted-foreground" />
          <input
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            placeholder="Name, @username, phone or email"
            className="pl-9 pr-4 py-2 text-sm rounded-lg bg-background border border-input placeholder:text-muted-foreground focus:outline-none focus:ring-1 focus:ring-ring w-56"
          />
        </div>
        <div className="relative">
          <Filter className="w-4 h-4 absolute left-3 top-1/2 -translate-y-1/2 text-muted-foreground" />
          <select
            value={bloodGroupFilter}
            onChange={(e) => setBloodGroupFilter(e.target.value)}
            className="pl-9 pr-8 py-2 text-sm rounded-lg bg-background border border-input focus:outline-none focus:ring-1 focus:ring-ring appearance-none"
          >
            <option value="">All Blood Groups</option>
            {BLOOD_GROUPS.map((bg) => <option key={bg} value={bg}>{bg}</option>)}
          </select>
        </div>
        <Button size="sm" variant={pending ? 'default' : 'secondary'} onClick={() => setPending(!pending)}>Pending verification</Button>
        <span className="text-xs text-muted-foreground">{filtered.length} loaded</span>
      </div>

      <Card className="overflow-hidden">
        <div className="overflow-x-auto">
          <Table>
            <TableHeader>
              <TableRow>
                <TableHead>Donor</TableHead>
                <TableHead>Blood Group</TableHead>
                <TableHead>Status</TableHead>
                <TableHead>Availability</TableHead>
                <TableHead>Account</TableHead>
                <TableHead>Actions</TableHead>
              </TableRow>
            </TableHeader>
            <TableBody>
              {loading
                ? [...Array(8)].map((_, i) => (
                    <TableRow key={i}>
                      <TableCell colSpan={6}>
                        <div className="h-8 bg-muted rounded animate-pulse" />
                      </TableCell>
                    </TableRow>
                  ))
                : filtered.map((donor) => (
                    <DonorRow
                      key={donor.id}
                      donor={donor}
                      busy={actionLoading}
                      onVerify={verifyDonor}
                      onToggle={toggleAvailability}
                      onBan={banUser}
                      onDelete={deleteDonor}
                    />
                  ))
              }
              {!loading && filtered.length === 0 && (
                <TableRow>
                  <TableCell colSpan={6} className="text-center py-12 text-muted-foreground text-sm">
                    No donors found.
                  </TableCell>
                </TableRow>
              )}
            </TableBody>
          </Table>
        </div>
      </Card>
      {hasMore && <Button disabled={loadingMore} onClick={loadMore}>{loadingMore ? 'Loading…' : 'Load more'}</Button>}
    </div>
  );
}
