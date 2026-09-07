/**
 * AnalyticsPage — charts computed client-side from live Firestore data
 * (see hooks/useFirebaseData.ts's useAnalytics) — no Cloud Function.
 */

import { useState } from 'react';
import { useAnalytics } from '../hooks/useFirebaseData';
import { BarChart3, TrendingUp, Droplets } from 'lucide-react';
import { Card } from '@/components/ui/card';
import { Button } from '@/components/ui/button';

type Period = '7d' | '30d' | '90d' | '12m';

const PERIODS: { value: Period; label: string }[] = [
  { value: '7d', label: '7 Days' },
  { value: '30d', label: '30 Days' },
  { value: '90d', label: '90 Days' },
  { value: '12m', label: '12 Months' },
];

const BLOOD_GROUP_COLORS: Record<string, string> = {
  'A+': 'bg-red-500', 'A-': 'bg-red-700',
  'B+': 'bg-blue-500', 'B-': 'bg-blue-700',
  'AB+': 'bg-purple-500', 'AB-': 'bg-purple-700',
  'O+': 'bg-emerald-500', 'O-': 'bg-emerald-700',
};

export default function AnalyticsPage() {
  const [period, setPeriod] = useState<Period>('30d');
  const { data, loading } = useAnalytics(period);

  const bloodGroups = data.bloodGroupDistribution;
  const maxBlood = Math.max(...bloodGroups.map((b) => b.count), 1);
  const urgencyData = data.fulfillmentRateByUrgency;
  const requestsByDay = data.requestsByDay;
  const topHospitals = data.topHospitals;

  return (
    <div className="p-6 space-y-6">
      <div className="flex items-center justify-between flex-wrap gap-3">
        <div>
          <h1 className="text-xl font-semibold">Analytics</h1>
          <p className="text-sm text-muted-foreground mt-0.5">
            {loading ? 'Loading…' : `Computed ${new Date(data.generatedAt).toLocaleTimeString()}`}
          </p>
        </div>
        <div className="flex gap-1.5">
          {PERIODS.map(({ value, label }) => (
            <Button key={value} size="sm" variant={period === value ? 'default' : 'secondary'} onClick={() => setPeriod(value)}>
              {label}
            </Button>
          ))}
        </div>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-5">
        <Card className="p-5">
          <div className="flex items-center gap-2 mb-4">
            <Droplets className="w-4 h-4 text-primary" />
            <h2 className="text-sm font-semibold">Donor Blood Group Distribution</h2>
          </div>
          {loading ? (
            <div className="space-y-2">
              {[...Array(8)].map((_, i) => <div key={i} className="h-8 bg-muted rounded animate-pulse" />)}
            </div>
          ) : bloodGroups.length === 0 ? (
            <p className="text-muted-foreground text-sm text-center py-8">No donor data yet.</p>
          ) : (
            <div className="space-y-2.5">
              {bloodGroups.map(({ group, count }) => (
                <div key={group} className="flex items-center gap-3">
                  <span className="text-xs font-bold w-8 text-right">{group}</span>
                  <div className="flex-1 bg-muted rounded-full h-2.5 overflow-hidden">
                    <div
                      className={`h-full rounded-full ${BLOOD_GROUP_COLORS[group] || 'bg-muted-foreground'} transition-all duration-500`}
                      style={{ width: `${(count / maxBlood) * 100}%` }}
                    />
                  </div>
                  <span className="text-xs text-muted-foreground w-6">{count}</span>
                </div>
              ))}
            </div>
          )}
        </Card>

        <Card className="p-5">
          <div className="flex items-center gap-2 mb-4">
            <TrendingUp className="w-4 h-4 text-emerald-500" />
            <h2 className="text-sm font-semibold">Fulfillment Rate by Urgency</h2>
          </div>
          {loading ? (
            <div className="space-y-3">{[...Array(3)].map((_, i) => <div key={i} className="h-16 bg-muted rounded animate-pulse" />)}</div>
          ) : urgencyData.length === 0 ? (
            <p className="text-muted-foreground text-sm text-center py-8">No request data in this period.</p>
          ) : (
            <div className="space-y-4">
              {urgencyData.map(({ urgency, rate, total, fulfilled }) => {
                const colors: Record<string, string> = {
                  critical: 'bg-red-500', urgent: 'bg-amber-500', normal: 'bg-blue-500',
                };
                return (
                  <div key={urgency}>
                    <div className="flex items-center justify-between mb-1.5">
                      <span className="text-xs font-medium capitalize">{urgency}</span>
                      <span className="text-xs text-muted-foreground">{fulfilled}/{total} · {rate}%</span>
                    </div>
                    <div className="bg-muted rounded-full h-2 overflow-hidden">
                      <div
                        className={`h-full rounded-full ${colors[urgency] || 'bg-muted-foreground'} transition-all duration-500`}
                        style={{ width: `${rate}%` }}
                      />
                    </div>
                  </div>
                );
              })}
            </div>
          )}
        </Card>

        <Card className="p-5">
          <div className="flex items-center gap-2 mb-4">
            <BarChart3 className="w-4 h-4 text-blue-500" />
            <h2 className="text-sm font-semibold">Request Activity</h2>
          </div>
          {loading ? (
            <div className="h-32 bg-muted rounded animate-pulse" />
          ) : requestsByDay.length === 0 ? (
            <p className="text-muted-foreground text-sm text-center py-8">No requests in this period.</p>
          ) : (
            <div className="overflow-x-auto">
              <div className="flex items-end gap-1 h-24 min-w-max">
                {requestsByDay.slice(-30).map(({ date, total, fulfilled }) => {
                  const maxVal = Math.max(...requestsByDay.map((r) => r.total), 1);
                  const pct = Math.round((total / maxVal) * 100);
                  const fulfilledPct = total > 0 ? Math.round((fulfilled / total) * pct) : 0;
                  return (
                    <div key={date} className="flex flex-col items-center gap-0.5 group relative" title={`${date}: ${total} total, ${fulfilled} fulfilled`}>
                      <div className="w-3 bg-muted rounded-sm overflow-hidden flex flex-col justify-end" style={{ height: '80px' }}>
                        <div className="w-full bg-emerald-500/60 rounded-sm" style={{ height: `${fulfilledPct}%` }} />
                        <div className="w-full bg-blue-500/40 rounded-sm" style={{ height: `${pct - fulfilledPct}%` }} />
                      </div>
                    </div>
                  );
                })}
              </div>
              <div className="flex gap-4 mt-2">
                <div className="flex items-center gap-1.5"><div className="w-2.5 h-2.5 rounded-sm bg-emerald-500/60" /><span className="text-xs text-muted-foreground">Fulfilled</span></div>
                <div className="flex items-center gap-1.5"><div className="w-2.5 h-2.5 rounded-sm bg-blue-500/40" /><span className="text-xs text-muted-foreground">Open/Other</span></div>
              </div>
            </div>
          )}
        </Card>

        <Card className="p-5">
          <h2 className="text-sm font-semibold mb-4">Top Hospitals by Request Volume</h2>
          {loading ? (
            <div className="space-y-2">{[...Array(5)].map((_, i) => <div key={i} className="h-8 bg-muted rounded animate-pulse" />)}</div>
          ) : topHospitals.length === 0 ? (
            <p className="text-muted-foreground text-sm text-center py-8">No hospital-linked requests yet.</p>
          ) : (
            <div className="space-y-3">
              {topHospitals.map(({ name, requestCount }, idx) => (
                <div key={name} className="flex items-center gap-3">
                  <span className="text-xs text-muted-foreground/70 w-4">{idx + 1}</span>
                  <p className="text-sm flex-1 truncate">{name}</p>
                  <span className="text-xs text-muted-foreground">{requestCount} requests</span>
                </div>
              ))}
            </div>
          )}
        </Card>
      </div>
    </div>
  );
}
