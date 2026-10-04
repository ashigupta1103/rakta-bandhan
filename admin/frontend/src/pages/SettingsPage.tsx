/**
 * SettingsPage — the owner's feature switches, stored in `config/features`
 * (read by the app, the edge Worker and firestore.rules; admin-write only).
 * Each one is a rollout step that must not be flipped early, so turning one
 * on shows what it does and asks first. A missing flag means off.
 */

import { useFeatureFlags, useAdminActions } from '../hooks/useFirebaseData';
import { Card } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Badge } from '@/components/ui/badge';

type Key = 'email_verified_required' | 'phone_required' | 'server_jobs';

const SWITCHES: { key: Key; title: string; what: string; warning: string }[] = [
  {
    key: 'email_verified_required',
    title: 'Require a proven email',
    what:
      'Only accounts that proved their email (the emailed sign-in code or a verified address) can create or change data. Off, any signed-in, non-anonymous account can.',
    warning:
      'Turn this on only after the emailed sign-in code is live (Blaze). While the email check is a simulation nobody has a proven email, so every member would lose the ability to post requests, photos and stories.',
  },
  {
    key: 'phone_required',
    title: 'Require a verified phone',
    what: 'A member needs a verified phone number to raise a request or accept one.',
    warning:
      'Phone verification is not live yet, so turning this on would stop every member from raising or accepting requests.',
  },
  {
    key: 'server_jobs',
    title: 'Server jobs are running',
    what:
      'Cloud Functions keep the Community Impact counter, and the app stops updating it itself. Request expiry and donor reactivation run from the same deployment.',
    warning: 'Turn this on only after the Cloud Functions are deployed. Until then nothing would update the Impact counter.',
  },
];

export default function SettingsPage() {
  const { flags, loading } = useFeatureFlags();
  const { setFeatureFlag, actionLoading, actionError } = useAdminActions();

  return (
    <div className="p-6 space-y-5 max-w-3xl">
      <div>
        <h1 className="text-xl font-semibold">Settings</h1>
        <p className="text-sm text-muted-foreground mt-0.5">
          Rollout switches for the whole app. Changes take effect for members within seconds.
          {flags.updated_at && ` Last changed ${flags.updated_at.toDate().toLocaleString()}.`}
        </p>
      </div>

      {actionError && <Card className="p-3 text-sm text-red-600 border-red-500/40">{actionError}</Card>}

      {SWITCHES.map(({ key, title, what, warning }) => {
        const on = flags[key] === true;
        return (
          <Card key={key} className="p-4 space-y-3">
            <div className="flex items-start gap-3">
              <div className="min-w-0 flex-1">
                <p className="text-sm font-medium">{title}</p>
                <p className="text-sm text-muted-foreground mt-1">{what}</p>
              </div>
              <Badge variant={on ? 'success' : 'secondary'}>{loading ? '…' : on ? 'On' : 'Off'}</Badge>
            </div>
            {!on && <p className="text-xs text-amber-600">{warning}</p>}
            <Button
              size="sm"
              variant={on ? 'outline' : 'default'}
              disabled={loading || actionLoading}
              onClick={() => {
                if (on || confirm(`${warning}\n\nTurn "${title}" on anyway?`)) setFeatureFlag(key, !on);
              }}
            >
              {on ? 'Turn off' : 'Turn on'}
            </Button>
          </Card>
        );
      })}
    </div>
  );
}
