/**
 * DonorsPage — Live donor list with verify, availability, and ban actions.
 * Writes go straight to Firestore (donors + donors_public dual-write) —
 * see hooks/useFirebaseData.ts for why (no admin* Cloud Functions on Spark).
 */

import { useState } from 'react';
import { useDonors, useAdminActions, type Donor } from '../hooks/useFirebaseData';
import { CheckCircle, AlertTriangle, Search, Filter } from 'lucide-react';
import { Card } from '@/components/ui/card';
import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import { Table, TableHeader, TableBody, TableRow, TableHead, TableCell } from '@/components/ui/table';

const BLOOD_GROUPS = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'];

function DonorRow({ donor, onVerify, onToggle, onBan, busy }: {
  donor: Donor;
  onVerify: (id: string, v: boolean, name: string) => void;
  onToggle: (id: string, v: boolean, name: string) => void;
  onBan: (id: string, v: boolean, name: string) => void;
  busy: boolean;
}) {
  return (
    <TableRow>
      <TableCell>
        <div className="flex items-center gap-2">
          <div className="w-7 h-7 rounded-full bg-muted flex items-center justify-center text-xs font-bold text-muted-foreground flex-shrink-0">
            {donor.name?.[0]?.toUpperCase() || '?'}
          </div>
          <div>
            <p className="text-sm font-medium">{donor.name}</p>
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
          <Button size="sm" variant="secondary" disabled={busy} onClick={() => onVerify(donor.id, !donor.is_verified, donor.name)}>
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
        </div>
      </TableCell>
    </TableRow>
  );
}

export default function DonorsPage() {
  const [bloodGroupFilter, setBloodGroupFilter] = useState('');
  const [search, setSearch] = useState('');
  const { donors, loading } = useDonors(bloodGroupFilter || undefined);
  const { actionLoading, actionError, verifyDonor, toggleAvailability, banUser } = useAdminActions();

  const filtered = donors.filter((d) =>
    !search ||
    d.name?.toLowerCase().includes(search.toLowerCase()) ||
    d.phone?.includes(search)
  );

  return (
    <div className="p-6 space-y-5">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-xl font-semibold">Donors</h1>
          <p className="text-sm text-muted-foreground mt-0.5">
            {loading ? '…' : `${donors.length} donors registered`}
          </p>
        </div>
      </div>

      {actionError && (
        <div className="bg-destructive/10 border border-destructive/30 rounded-lg px-4 py-3 text-destructive text-sm">
          {actionError}
        </div>
      )}

      <div className="flex items-center gap-3 flex-wrap">
        <div className="relative">
          <Search className="w-4 h-4 absolute left-3 top-1/2 -translate-y-1/2 text-muted-foreground" />
          <input
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            placeholder="Search name or phone…"
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
        <span className="text-xs text-muted-foreground">{filtered.length} results</span>
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
    </div>
  );
}
