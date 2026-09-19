/**
 * BroadcastPage — Compose a notification blast to donors.
 *
 * Real FCM delivery needs adminBroadcastNotification.js, which needs the
 * Blaze plan (not enabled on this project — see BACKEND_REFERENCE.md).
 * Submitting here still queries the real matching donor count and logs
 * the intent to /broadcasts + the audit log, so the flow demos honestly
 * end-to-end instead of a dead form.
 */

import { useState } from 'react';
import { useAdminActions } from '../hooks/useFirebaseData';
import { Bell, Send, Info } from 'lucide-react';
import { Card } from '@/components/ui/card';
import { Button } from '@/components/ui/button';

const BLOOD_GROUPS = ['', 'A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'];

interface BroadcastResult {
  sent: number;
  failed: number;
  targeted: number;
  message: string;
}

export default function BroadcastPage() {
  const { actionLoading, broadcastNotification } = useAdminActions();
  const [title, setTitle] = useState('');
  const [body, setBody] = useState('');
  const [bloodGroup, setBloodGroup] = useState('');
  const [availableOnly, setAvailableOnly] = useState(true);
  const [result, setResult] = useState<BroadcastResult | null>(null);
  const [error, setError] = useState('');

  async function handleSend(e: React.FormEvent) {
    e.preventDefault();
    setResult(null);
    setError('');

    if (!confirm(`Queue "${title}" for ${bloodGroup || 'all'} donors?`)) return;

    try {
      const res = await broadcastNotification({
        title,
        body,
        bloodGroup: bloodGroup || undefined,
        availableOnly,
      });
      setResult(res);
      setTitle('');
      setBody('');
    } catch (err: unknown) {
      setError(err instanceof Error ? err.message : 'Broadcast failed');
    }
  }

  return (
    <div className="p-6 space-y-5">
      <div>
        <h1 className="text-xl font-semibold">Broadcast Notification</h1>
        <p className="text-sm text-muted-foreground mt-0.5">
          Compose a message for verified donors.
        </p>
      </div>

      <div className="max-w-xl">
        <div className="mb-4 flex items-start gap-2 rounded-lg border border-amber-500/30 bg-amber-500/10 px-4 py-3">
          <Info className="w-4 h-4 text-amber-600 flex-shrink-0 mt-0.5" />
          <p className="text-xs text-amber-700">
            Push delivery requires the Blaze plan. Sending here targets and logs the real matching
            donor count, but no device notification goes out until Cloud Functions are deployed.
          </p>
        </div>

        <Card className="p-6 space-y-4">
          <form onSubmit={handleSend} className="space-y-4">
            <div>
              <label className="block text-xs font-medium text-muted-foreground mb-1.5">Notification Title *</label>
              <input
                value={title}
                onChange={(e) => setTitle(e.target.value)}
                required
                maxLength={80}
                placeholder="e.g., Urgent: O- Blood Needed"
                className="w-full px-3 py-2.5 rounded-lg bg-background border border-input text-sm placeholder:text-muted-foreground focus:outline-none focus:ring-1 focus:ring-ring"
              />
            </div>

            <div>
              <label className="block text-xs font-medium text-muted-foreground mb-1.5">Message Body *</label>
              <textarea
                value={body}
                onChange={(e) => setBody(e.target.value)}
                required
                rows={3}
                maxLength={200}
                placeholder="Enter the notification message…"
                className="w-full px-3 py-2.5 rounded-lg bg-background border border-input text-sm placeholder:text-muted-foreground focus:outline-none focus:ring-1 focus:ring-ring resize-none"
              />
              <p className="text-xs text-muted-foreground mt-1">{body.length}/200 characters</p>
            </div>

            <div className="grid grid-cols-2 gap-4">
              <div>
                <label className="block text-xs font-medium text-muted-foreground mb-1.5">Filter by Blood Group</label>
                <select
                  value={bloodGroup}
                  onChange={(e) => setBloodGroup(e.target.value)}
                  className="w-full px-3 py-2.5 rounded-lg bg-background border border-input text-sm focus:outline-none focus:ring-1 focus:ring-ring"
                >
                  <option value="">All Blood Groups</option>
                  {BLOOD_GROUPS.filter(Boolean).map((bg) => (
                    <option key={bg} value={bg}>{bg}</option>
                  ))}
                </select>
              </div>

              <div className="flex flex-col justify-end">
                <label className="flex items-center gap-2.5 cursor-pointer">
                  <div
                    onClick={() => setAvailableOnly(!availableOnly)}
                    className={`w-9 h-5 rounded-full transition-colors relative ${availableOnly ? 'bg-primary' : 'bg-muted'}`}
                  >
                    <div
                      className="w-3.5 h-3.5 bg-background rounded-full absolute transition-all"
                      style={{ top: '3px', left: availableOnly ? '18px' : '3px' }}
                    />
                  </div>
                  <span className="text-xs text-muted-foreground">Available donors only</span>
                </label>
              </div>
            </div>

            {error && (
              <div className="bg-destructive/10 border border-destructive/30 rounded-lg px-4 py-3 text-destructive text-sm">
                {error}
              </div>
            )}

            {result && (
              <div className="bg-emerald-500/10 border border-emerald-500/30 rounded-lg px-4 py-3">
                <p className="text-emerald-600 text-sm font-medium mb-1">Queued</p>
                <p className="text-xs text-muted-foreground">{result.message}</p>
                <div className="flex gap-4 mt-2">
                  <span className="text-xs text-muted-foreground">Targeted: <strong className="text-foreground">{result.targeted}</strong></span>
                </div>
              </div>
            )}

            <Button type="submit" disabled={actionLoading || !title || !body} className="w-full">
              {actionLoading ? 'Queuing…' : <><Send className="w-4 h-4" /> Queue Broadcast</>}
            </Button>
          </form>
        </Card>

        <div className="mt-4 bg-card/50 border border-border rounded-lg p-4">
          <div className="flex items-center gap-2 mb-2">
            <Bell className="w-3.5 h-3.5 text-muted-foreground" />
            <span className="text-xs font-medium text-muted-foreground">Usage Guidelines</span>
          </div>
          <ul className="text-xs text-muted-foreground/70 space-y-1 list-disc list-inside">
            <li>Targets verified donors matching your filters</li>
            <li>All broadcasts are logged in the Audit Log</li>
            <li>Live push delivery needs the Blaze plan upgrade</li>
          </ul>
        </div>
      </div>
    </div>
  );
}
