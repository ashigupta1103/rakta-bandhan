import type { LucideIcon } from 'lucide-react';
import { Card } from '@/components/ui/card';
import { cn } from '@/lib/utils';

export function StatCard({
  label,
  value,
  sub,
  icon: Icon,
  tone = 'default',
  loading,
  highlight = false,
}: {
  label: string;
  value: number | string;
  sub?: string;
  icon: LucideIcon;
  tone?: 'default' | 'success' | 'warning' | 'destructive' | 'info';
  loading?: boolean;
  /** Renders as a solid brand-red card — reserve for the one metric that
   * matters most on the page (see DashboardHome). Never more than one. */
  highlight?: boolean;
}) {
  const toneClasses: Record<string, string> = {
    default: 'bg-primary/10 text-primary',
    success: 'bg-emerald-500/10 text-emerald-600',
    warning: 'bg-amber-500/10 text-amber-600',
    destructive: 'bg-red-500/10 text-red-600',
    info: 'bg-blue-500/10 text-blue-600',
  };

  if (highlight) {
    return (
      <Card className="border-transparent bg-primary p-5 text-primary-foreground">
        <div className="mb-3 flex h-9 w-9 items-center justify-center rounded-lg bg-white/15">
          <Icon className="h-4.5 w-4.5" />
        </div>
        {loading ? (
          <div className="mb-1 h-8 w-16 animate-pulse rounded bg-white/20" />
        ) : (
          <p className="text-2xl font-semibold tabular-nums">{value}</p>
        )}
        <p className="mt-0.5 text-sm text-primary-foreground/85">{label}</p>
        {sub && <p className="mt-1 text-xs text-primary-foreground/60">{sub}</p>}
      </Card>
    );
  }

  return (
    <Card className="p-5">
      <div className={cn('mb-3 flex h-9 w-9 items-center justify-center rounded-lg', toneClasses[tone])}>
        <Icon className="h-4.5 w-4.5" />
      </div>
      {loading ? (
        <div className="mb-1 h-8 w-16 animate-pulse rounded bg-muted" />
      ) : (
        <p className="text-2xl font-semibold tabular-nums text-foreground">{value}</p>
      )}
      <p className="mt-0.5 text-sm text-muted-foreground">{label}</p>
      {sub && <p className="mt-1 text-xs text-muted-foreground/70">{sub}</p>}
    </Card>
  );
}
