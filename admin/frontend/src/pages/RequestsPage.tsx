/**
 * RequestsPage — Live blood requests with real-time status updates.
 */

import { useState } from 'react';
import { useRequests } from '../hooks/useFirebaseData';
import { Droplets, Clock, AlertTriangle } from 'lucide-react';
import { Card } from '@/components/ui/card';
import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import { Table, TableHeader, TableBody, TableRow, TableHead, TableCell } from '@/components/ui/table';
import { cn } from '@/lib/utils';

const STATUS_FILTER_OPTIONS = ['all', 'open', 'matched', 'fulfilled', 'expired', 'cancelled'];

const URGENCY_VARIANT: Record<string, 'destructive' | 'warning' | 'info'> = {
  critical: 'destructive',
  urgent: 'warning',
  normal: 'info',
};

const STATUS_VARIANT: Record<string, 'info' | 'warning' | 'success' | 'secondary' | 'destructive'> = {
  open: 'info',
  matched: 'warning',
  fulfilled: 'success',
  expired: 'secondary',
  cancelled: 'destructive',
};

function UrgencyIcon({ urgency }: { urgency: string }) {
  if (urgency === 'critical') return <AlertTriangle className="w-3.5 h-3.5" />;
  if (urgency === 'urgent') return <Clock className="w-3.5 h-3.5" />;
  return <Droplets className="w-3.5 h-3.5" />;
}

function timeAgo(ts: { toDate: () => Date } | undefined): string {
  if (!ts) return '—';
  const diff = Date.now() - ts.toDate().getTime();
  const m = Math.floor(diff / 60000);
  if (m < 60) return `${m}m ago`;
  const h = Math.floor(m / 60);
  if (h < 24) return `${h}h ago`;
  return `${Math.floor(h / 24)}d ago`;
}

export default function RequestsPage() {
  const [statusFilter, setStatusFilter] = useState('all');
  const { requests, loading } = useRequests(statusFilter);

  const openCount = requests.filter((r) => r.status === 'open').length;
  const criticalCount = requests.filter((r) => r.urgency === 'critical' && r.status === 'open').length;

  return (
    <div className="p-6 space-y-5">
      <div className="flex items-center justify-between flex-wrap gap-3">
        <div>
          <h1 className="text-xl font-semibold">Blood Requests</h1>
          <p className="text-sm text-muted-foreground mt-0.5">
            {loading ? '…' : `${requests.length} total · ${openCount} open · ${criticalCount} critical`}
          </p>
        </div>

        <div className="flex gap-1.5 flex-wrap">
          {STATUS_FILTER_OPTIONS.map((s) => (
            <Button
              key={s}
              size="sm"
              variant={statusFilter === s ? 'default' : 'secondary'}
              className="capitalize rounded-full"
              onClick={() => setStatusFilter(s)}
            >
              {s}
            </Button>
          ))}
        </div>
      </div>

      <div className="flex items-center gap-2">
        <div className="w-1.5 h-1.5 rounded-full bg-emerald-500 animate-pulse" />
        <span className="text-xs text-muted-foreground">Auto-updating in real-time via Firestore</span>
      </div>

      <Card className="overflow-hidden">
        <div className="overflow-x-auto">
          <Table>
            <TableHeader>
              <TableRow>
                <TableHead>Blood Group</TableHead>
                <TableHead>Urgency</TableHead>
                <TableHead>Units</TableHead>
                <TableHead>Status</TableHead>
                <TableHead>Requester</TableHead>
                <TableHead>Created</TableHead>
                <TableHead>Expires</TableHead>
              </TableRow>
            </TableHeader>
            <TableBody>
              {loading
                ? [...Array(10)].map((_, i) => (
                    <TableRow key={i}>
                      <TableCell colSpan={7}>
                        <div className="h-6 bg-muted rounded animate-pulse" />
                      </TableCell>
                    </TableRow>
                  ))
                : requests.map((req) => (
                    <TableRow key={req.id}>
                      <TableCell>
                        <span className="text-sm font-bold text-primary">{req.blood_group}</span>
                      </TableCell>
                      <TableCell>
                        <Badge variant={URGENCY_VARIANT[req.urgency] || 'secondary'} className={cn('capitalize')}>
                          <UrgencyIcon urgency={req.urgency} />
                          {req.urgency}
                        </Badge>
                      </TableCell>
                      <TableCell>{req.units_needed}</TableCell>
                      <TableCell>
                        <Badge variant={STATUS_VARIANT[req.status] || 'secondary'} className="capitalize">
                          {req.status}
                        </Badge>
                      </TableCell>
                      <TableCell>
                        <span className="text-xs text-muted-foreground font-mono">{req.requester_uid?.slice(0, 8)}…</span>
                      </TableCell>
                      <TableCell>
                        <span className="text-xs text-muted-foreground">{timeAgo(req.created_at)}</span>
                      </TableCell>
                      <TableCell>
                        <span className="text-xs text-muted-foreground">{timeAgo(req.expires_at)}</span>
                      </TableCell>
                    </TableRow>
                  ))
              }
              {!loading && requests.length === 0 && (
                <TableRow>
                  <TableCell colSpan={7} className="text-center py-12 text-muted-foreground text-sm">
                    No requests found for this filter.
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
