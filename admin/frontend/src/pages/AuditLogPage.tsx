/**
 * AuditLogPage — live admin action trail (most recent 100), written
 * directly by the admin panel itself (see logAudit in useFirebaseData.ts) —
 * setAdminRole.js's audit write is the Blaze-only equivalent.
 */

import { useAuditLog } from '../hooks/useFirebaseData';
import { Shield } from 'lucide-react';
import { Card } from '@/components/ui/card';
import { Badge } from '@/components/ui/badge';
import { Table, TableHeader, TableBody, TableRow, TableHead, TableCell } from '@/components/ui/table';

const ACTION_VARIANT: Record<string, 'success' | 'warning' | 'destructive' | 'info' | 'secondary'> = {
  VERIFY_DONOR: 'success',
  UNVERIFY_DONOR: 'warning',
  ACTIVATE_DONOR: 'success',
  DEACTIVATE_DONOR: 'secondary',
  BAN_USER: 'destructive',
  UNBAN_USER: 'success',
  CREATE_HOSPITAL: 'info',
  VERIFY_HOSPITAL: 'success',
  UNVERIFY_HOSPITAL: 'warning',
  DELETE_HOSPITAL: 'destructive',
  BROADCAST_NOTIFICATION: 'info',
};

export default function AuditLogPage() {
  const { entries, loading } = useAuditLog();

  return (
    <div className="p-6 space-y-5">
      <div>
        <h1 className="text-xl font-semibold">Audit Log</h1>
        <p className="text-sm text-muted-foreground mt-0.5">Live trail of admin actions on this panel.</p>
      </div>

      <Card className="overflow-hidden">
        <div className="overflow-x-auto">
          <Table>
            <TableHeader>
              <TableRow>
                <TableHead>Action</TableHead>
                <TableHead>Performed By</TableHead>
                <TableHead>Target</TableHead>
                <TableHead>Reason</TableHead>
                <TableHead>Time</TableHead>
              </TableRow>
            </TableHeader>
            <TableBody>
              {loading
                ? [...Array(10)].map((_, i) => (
                    <TableRow key={i}>
                      <TableCell colSpan={5}>
                        <div className="h-6 bg-muted rounded animate-pulse" />
                      </TableCell>
                    </TableRow>
                  ))
                : entries.map((entry) => (
                    <TableRow key={entry.id}>
                      <TableCell>
                        <Badge variant={ACTION_VARIANT[entry.action] || 'secondary'}>
                          {entry.action.replace(/_/g, ' ')}
                        </Badge>
                      </TableCell>
                      <TableCell className="text-xs text-muted-foreground">{entry.performed_by}</TableCell>
                      <TableCell>
                        <p className="text-xs">{entry.target_name || '—'}</p>
                        {entry.target_uid && <p className="text-xs text-muted-foreground/70 font-mono">{entry.target_uid.slice(0, 10)}…</p>}
                      </TableCell>
                      <TableCell className="text-xs text-muted-foreground">{entry.reason || '—'}</TableCell>
                      <TableCell className="text-xs text-muted-foreground">
                        {entry.at ? entry.at.toDate().toLocaleString('en-IN') : '—'}
                      </TableCell>
                    </TableRow>
                  ))
              }
              {!loading && entries.length === 0 && (
                <TableRow>
                  <TableCell colSpan={5} className="text-center py-12">
                    <Shield className="w-8 h-8 text-muted-foreground/40 mx-auto mb-2" />
                    <p className="text-muted-foreground text-sm">No admin actions logged yet.</p>
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
