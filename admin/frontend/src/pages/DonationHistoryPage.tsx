/**
 * DonationHistoryPage — fulfilled requests, read-only.
 *
 * Derived from /requests where status == 'fulfilled' rather than the
 * dormant /donation_history collection (that was written by the
 * Blaze-only onDonationConfirmed.js Cloud Function). Donors self-report
 * completion in the app, so a fulfilled request *is* the donation record
 * on the Spark plan — see hooks/useFirebaseData.ts.
 */

import { useDonationHistory } from '../hooks/useFirebaseData';
import { History, CheckCircle } from 'lucide-react';
import { Card } from '@/components/ui/card';
import { Table, TableHeader, TableBody, TableRow, TableHead, TableCell } from '@/components/ui/table';

function timeStr(ts: { toDate: () => Date } | undefined): string {
  if (!ts) return '—';
  return ts.toDate().toLocaleDateString('en-IN', { day: '2-digit', month: 'short', year: 'numeric' });
}

export default function DonationHistoryPage() {
  const { donations, loading } = useDonationHistory();

  return (
    <div className="p-6 space-y-5">
      <div>
        <h1 className="text-xl font-semibold">Donation History</h1>
        <p className="text-sm text-muted-foreground mt-0.5">
          {loading ? '…' : `${donations.length} donation(s) recorded (self-reported by donors)`}
        </p>
      </div>

      <Card className="overflow-hidden">
        <div className="overflow-x-auto">
          <Table>
            <TableHeader>
              <TableRow>
                <TableHead>Request</TableHead>
                <TableHead>Blood Group</TableHead>
                <TableHead>Donor UID</TableHead>
                <TableHead>Requester UID</TableHead>
                <TableHead>Donated</TableHead>
              </TableRow>
            </TableHeader>
            <TableBody>
              {loading
                ? [...Array(8)].map((_, i) => (
                    <TableRow key={i}>
                      <TableCell colSpan={5}>
                        <div className="h-6 bg-muted rounded animate-pulse" />
                      </TableCell>
                    </TableRow>
                  ))
                : donations.map((d) => (
                    <TableRow key={d.id}>
                      <TableCell>
                        <div className="flex items-center gap-1.5">
                          <CheckCircle className="w-3.5 h-3.5 text-emerald-500" />
                          <span className="text-xs text-muted-foreground font-mono">{d.id.slice(0, 10)}…</span>
                        </div>
                      </TableCell>
                      <TableCell><span className="text-sm font-bold text-primary">{d.blood_group}</span></TableCell>
                      <TableCell className="text-xs text-muted-foreground font-mono">{d.matched_donor_id?.slice(0, 10) || '—'}…</TableCell>
                      <TableCell className="text-xs text-muted-foreground font-mono">{d.requester_uid?.slice(0, 10)}…</TableCell>
                      <TableCell className="text-xs">{timeStr(d.fulfilled_at)}</TableCell>
                    </TableRow>
                  ))
              }
              {!loading && donations.length === 0 && (
                <TableRow>
                  <TableCell colSpan={5} className="text-center py-12">
                    <History className="w-8 h-8 text-muted-foreground/40 mx-auto mb-2" />
                    <p className="text-muted-foreground text-sm">No donations confirmed yet.</p>
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
