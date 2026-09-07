/**
 * DashboardHome — Overview with live KPI cards + recent activity.
 * Stats are computed client-side from Firestore listeners (see
 * hooks/useFirebaseData.ts) — no Cloud Function involved.
 */

import { useDashboardStats } from '../hooks/useFirebaseData';
import { Users, Droplets, Building2, Activity, TrendingUp, Clock, CheckCircle, XCircle } from 'lucide-react';
import { StatCard } from '@/components/stat-card';
import { Card } from '@/components/ui/card';
import { Badge } from '@/components/ui/badge';

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

export default function DashboardHome() {
  const { stats, loading } = useDashboardStats();

  return (
    <div className="p-6 space-y-6">
      <div>
        <h1 className="text-xl font-semibold">Dashboard Overview</h1>
        <p className="text-sm text-muted-foreground mt-0.5">Real-time metrics from Firestore.</p>
      </div>

      {/* KPI Grid */}
      <div className="grid grid-cols-2 lg:grid-cols-4 gap-4">
        <StatCard loading={loading} label="Total Donors" value={stats.totalDonors}
          sub={`${stats.verifiedDonors} verified`} icon={Users} />
        <StatCard loading={loading} label="Available Donors" value={stats.availableDonors}
          sub="Ready to donate" icon={Activity} tone="success" />
        <StatCard loading={loading} label="Open Requests" value={stats.openRequests}
          sub={`${stats.totalRequests} total`} icon={Droplets} highlight />
        <StatCard loading={loading} label="Hospitals" value={stats.totalHospitals}
          sub={`${stats.verifiedHospitals} verified`} icon={Building2} tone="info" />
        <StatCard loading={loading} label="Total Donations" value={stats.totalDonations}
          sub={`${stats.donationsThisMonth} this month`} icon={CheckCircle} tone="success" />
        <StatCard loading={loading} label="Fulfillment Rate" value={`${stats.fulfillmentRate}%`}
          sub="Requests fulfilled" icon={TrendingUp} />
        <StatCard loading={loading} label="Avg Response Time" value={`${stats.avgResponseTimeMinutes}m`}
          sub="Request → match" icon={Clock} tone="warning" />
        <StatCard loading={loading} label="Banned Users" value={stats.bannedUsers}
          sub="Total bans" icon={XCircle} tone="destructive" />
      </div>

      {/* Recent Activity */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-4">
        <Card className="p-5">
          <h2 className="text-sm font-semibold mb-4">Recent Blood Requests</h2>
          {loading ? (
            <div className="space-y-3">
              {[...Array(5)].map((_, i) => (
                <div key={i} className="h-10 bg-muted rounded animate-pulse" />
              ))}
            </div>
          ) : (
            <div className="space-y-2">
              {stats.recentRequests.map((req) => (
                <div key={req.id} className="flex items-center gap-3 py-2 border-b border-border/60 last:border-0">
                  <Badge variant={URGENCY_VARIANT[req.urgency] || 'secondary'}>{req.blood_group}</Badge>
                  <Badge variant={STATUS_VARIANT[req.status] || 'secondary'} className="capitalize">{req.status}</Badge>
                  <span className="text-xs text-muted-foreground ml-auto">
                    {req.urgency} · {req.units_needed} unit(s)
                  </span>
                </div>
              ))}
              {stats.recentRequests.length === 0 && (
                <p className="text-sm text-muted-foreground text-center py-4">No requests yet</p>
              )}
            </div>
          )}
        </Card>

        <Card className="p-5">
          <h2 className="text-sm font-semibold mb-4">Recently Registered Donors</h2>
          {loading ? (
            <div className="space-y-3">
              {[...Array(5)].map((_, i) => (
                <div key={i} className="h-10 bg-muted rounded animate-pulse" />
              ))}
            </div>
          ) : (
            <div className="space-y-2">
              {stats.recentDonors.map((donor) => (
                <div key={donor.id} className="flex items-center gap-3 py-2 border-b border-border/60 last:border-0">
                  <div className="w-7 h-7 rounded-full bg-muted flex items-center justify-center text-xs font-bold text-muted-foreground">
                    {donor.name?.[0]?.toUpperCase() || '?'}
                  </div>
                  <div className="min-w-0">
                    <p className="text-sm truncate">{donor.name}</p>
                    <p className="text-xs text-muted-foreground">{donor.blood_group}</p>
                  </div>
                  <div className="ml-auto">
                    <Badge variant={donor.is_verified ? 'success' : 'warning'}>
                      {donor.is_verified ? 'Verified' : 'Pending'}
                    </Badge>
                  </div>
                </div>
              ))}
              {stats.recentDonors.length === 0 && (
                <p className="text-sm text-muted-foreground text-center py-4">No donors yet</p>
              )}
            </div>
          )}
        </Card>
      </div>
    </div>
  );
}
