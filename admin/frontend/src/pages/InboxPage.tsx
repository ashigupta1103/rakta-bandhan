/**
 * InboxPage — every one-way submission the app can generate, triaged.
 *
 * "Report an issue" (Help & support) writes `issue_reports`; "Start a
 * conversation" (Corporate partnerships) writes `partnership_inquiries`;
 * a chat/call block-and-report (ChatService.report) writes `reports`. All
 * three are create-only for the submitter and admin-updatable per
 * firestore.rules, so triage here is a plain field write: status
 * New → In progress → Resolved, plus an internal note. There is no reply
 * channel — sending mail needs a server, which this project's Spark plan
 * doesn't run — so the note is admin-only and the page says so.
 * `reports` specifically has no delete in the rules (an abuse report stays
 * on record regardless of outcome), so that section has no delete button.
 */

import { useMemo, useState } from 'react';
import {
  useIssueReports,
  usePartnershipInquiries,
  useAbuseReports,
  useAdminActions,
  INBOX_STATUSES,
  INBOX_STATUS_LABELS,
  type InboxStatus,
} from '../hooks/useFirebaseData';
import { Flag, Handshake, ShieldAlert, Trash2, StickyNote, Inbox } from 'lucide-react';
import { Card } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Badge } from '@/components/ui/badge';
import { cn } from '../lib/utils';

const STATUS_VARIANT: Record<InboxStatus, 'destructive' | 'warning' | 'success'> = {
  new: 'destructive',
  in_progress: 'warning',
  resolved: 'success',
};

function statusOf(raw?: string): InboxStatus {
  return raw === 'in_progress' || raw === 'resolved' ? raw : 'new';
}

function timeAgo(ts?: { toDate: () => Date }) {
  if (!ts) return '';
  const diff = Date.now() - ts.toDate().getTime();
  const mins = Math.floor(diff / 60000);
  if (mins < 1) return 'just now';
  if (mins < 60) return `${mins} min ago`;
  const hours = Math.floor(mins / 60);
  if (hours < 24) return `${hours}h ago`;
  return `${Math.floor(hours / 24)}d ago`;
}

export default function InboxPage() {
  const { reports, loading: reportsLoading } = useIssueReports();
  const { inquiries, loading: inquiriesLoading } = usePartnershipInquiries();
  const { reports: abuseReports, loading: abuseLoading } = useAbuseReports();
  const {
    actionError,
    setIssueStatus,
    deleteIssueReport,
    setInquiryStatus,
    deleteInquiry,
    setReportStatus,
  } = useAdminActions();

  const [filter, setFilter] = useState<InboxStatus | 'all'>('all');
  const loading = reportsLoading || inquiriesLoading || abuseLoading;

  const visibleReports = useMemo(
    () => reports.filter((r) => filter === 'all' || statusOf(r.status) === filter),
    [reports, filter]
  );
  const visibleInquiries = useMemo(
    () => inquiries.filter((i) => filter === 'all' || statusOf(i.status) === filter),
    [inquiries, filter]
  );
  const visibleAbuseReports = useMemo(
    () => abuseReports.filter((r) => filter === 'all' || statusOf(r.status) === filter),
    [abuseReports, filter]
  );

  const unresolved =
    reports.filter((r) => statusOf(r.status) !== 'resolved').length +
    inquiries.filter((i) => statusOf(i.status) !== 'resolved').length +
    abuseReports.filter((r) => statusOf(r.status) !== 'resolved').length;

  async function editNote(current: string, save: (note: string) => Promise<unknown>) {
    const next = window.prompt('Internal note — only admins can read this.', current);
    if (next === null) return;
    await save(next);
  }

  return (
    <div className="p-6 space-y-5">
      <div>
        <h1 className="text-xl font-semibold">Inbox</h1>
        <p className="text-sm text-muted-foreground mt-0.5">
          {loading
            ? '…'
            : `${abuseReports.length} abuse report(s) · ${reports.length} issue report(s) · ${inquiries.length} partnership inquiry(s) · ${unresolved} unresolved`}
        </p>
      </div>

      {actionError && (
        <Card className="p-3 text-sm text-red-600 border-red-500/40">{actionError}</Card>
      )}

      <div className="flex flex-wrap gap-2">
        {(['all', ...INBOX_STATUSES] as const).map((value) => (
          <button
            key={value}
            onClick={() => setFilter(value)}
            className={cn(
              'px-3 py-1.5 rounded-full text-xs font-medium border transition-colors',
              filter === value
                ? 'bg-primary text-primary-foreground border-transparent'
                : 'border-border text-muted-foreground hover:text-foreground hover:bg-accent'
            )}
          >
            {value === 'all' ? 'All' : INBOX_STATUS_LABELS[value]}
          </button>
        ))}
      </div>

      {!loading && visibleReports.length === 0 && visibleInquiries.length === 0 && visibleAbuseReports.length === 0 && (
        <Card className="p-8 flex flex-col items-center gap-2 text-center">
          <Inbox className="w-6 h-6 text-muted-foreground" />
          <p className="text-sm text-muted-foreground">
            {filter === 'all'
              ? 'Nothing submitted yet. Reports from Help & support, inquiries from Corporate partnerships, and chat/call reports land here.'
              : `Nothing is ${INBOX_STATUS_LABELS[filter].toLowerCase()}.`}
          </p>
        </Card>
      )}

      {visibleAbuseReports.length > 0 && (
        <section className="space-y-3">
          <h2 className="flex items-center gap-2 text-xs font-semibold uppercase tracking-wider text-muted-foreground">
            <ShieldAlert className="w-3.5 h-3.5" /> Chat &amp; call reports
          </h2>
          {visibleAbuseReports.map((report) => {
            const status = statusOf(report.status);
            return (
              <Card key={report.id} className="p-4 space-y-3">
                <div className="flex items-start gap-3">
                  <div className="min-w-0 flex-1">
                    <p className="text-sm font-medium">{report.reason}</p>
                    <p className="text-xs text-muted-foreground font-mono mt-0.5">
                      reported {report.reported_uid} · request {report.request_id}
                    </p>
                    {report.details && (
                      <p className="text-sm text-muted-foreground mt-1 whitespace-pre-wrap">{report.details}</p>
                    )}
                    <p className="text-xs text-muted-foreground mt-2">{timeAgo(report.created_at)}</p>
                  </div>
                  <Badge variant={STATUS_VARIANT[status]}>{INBOX_STATUS_LABELS[status]}</Badge>
                </div>

                {report.admin_note && (
                  <p className="text-xs text-muted-foreground border-l-2 border-border pl-3 py-1 whitespace-pre-wrap">
                    {report.admin_note}
                  </p>
                )}

                <div className="flex flex-wrap items-center gap-2 pt-1 border-t border-border">
                  {INBOX_STATUSES.map((s) => (
                    <button
                      key={s}
                      onClick={() => setReportStatus(report.id, s)}
                      disabled={s === status}
                      className={cn(
                        'px-2.5 py-1 rounded-full text-xs border transition-colors',
                        s === status
                          ? 'bg-primary/10 text-primary border-transparent'
                          : 'border-border text-muted-foreground hover:text-foreground hover:bg-accent'
                      )}
                    >
                      {INBOX_STATUS_LABELS[s]}
                    </button>
                  ))}
                  <div className="flex-1" />
                  <Button
                    variant="ghost"
                    size="sm"
                    onClick={() =>
                      editNote(report.admin_note || '', (note) => setReportStatus(report.id, status, note))
                    }
                  >
                    <StickyNote className="w-3.5 h-3.5" /> {report.admin_note ? 'Edit note' : 'Add note'}
                  </Button>
                </div>
              </Card>
            );
          })}
        </section>
      )}

      {visibleReports.length > 0 && (
        <section className="space-y-3">
          <h2 className="flex items-center gap-2 text-xs font-semibold uppercase tracking-wider text-muted-foreground">
            <Flag className="w-3.5 h-3.5" /> Issue reports
          </h2>
          {visibleReports.map((report) => {
            const status = statusOf(report.status);
            return (
              <Card key={report.id} className="p-4 space-y-3">
                <div className="flex items-start gap-3">
                  <div className="min-w-0 flex-1">
                    <p className="text-sm font-medium">{report.reason}</p>
                    {report.details && (
                      <p className="text-sm text-muted-foreground mt-1 whitespace-pre-wrap">{report.details}</p>
                    )}
                    <p className="text-xs text-muted-foreground mt-2">{timeAgo(report.created_at)}</p>
                  </div>
                  <Badge variant={STATUS_VARIANT[status]}>{INBOX_STATUS_LABELS[status]}</Badge>
                </div>

                {report.admin_note && (
                  <p className="text-xs text-muted-foreground border-l-2 border-border pl-3 py-1 whitespace-pre-wrap">
                    {report.admin_note}
                  </p>
                )}

                <div className="flex flex-wrap items-center gap-2 pt-1 border-t border-border">
                  {INBOX_STATUSES.map((s) => (
                    <button
                      key={s}
                      onClick={() => setIssueStatus(report.id, s)}
                      disabled={s === status}
                      className={cn(
                        'px-2.5 py-1 rounded-full text-xs border transition-colors',
                        s === status
                          ? 'bg-primary/10 text-primary border-transparent'
                          : 'border-border text-muted-foreground hover:text-foreground hover:bg-accent'
                      )}
                    >
                      {INBOX_STATUS_LABELS[s]}
                    </button>
                  ))}
                  <div className="flex-1" />
                  <Button
                    variant="ghost"
                    size="sm"
                    onClick={() =>
                      editNote(report.admin_note || '', (note) => setIssueStatus(report.id, status, note))
                    }
                  >
                    <StickyNote className="w-3.5 h-3.5" /> {report.admin_note ? 'Edit note' : 'Add note'}
                  </Button>
                  <Button
                    variant="ghost"
                    size="sm"
                    className="text-red-600"
                    onClick={() => {
                      if (confirm('Delete this report? This cannot be undone.')) deleteIssueReport(report.id);
                    }}
                  >
                    <Trash2 className="w-3.5 h-3.5" />
                  </Button>
                </div>
              </Card>
            );
          })}
        </section>
      )}

      {visibleInquiries.length > 0 && (
        <section className="space-y-3">
          <h2 className="flex items-center gap-2 text-xs font-semibold uppercase tracking-wider text-muted-foreground">
            <Handshake className="w-3.5 h-3.5" /> Partnership inquiries
          </h2>
          {visibleInquiries.map((inquiry) => {
            const status = statusOf(inquiry.status);
            return (
              <Card key={inquiry.id} className="p-4 space-y-3">
                <div className="flex items-start gap-3">
                  <div className="min-w-0 flex-1">
                    <p className="text-sm font-medium">{inquiry.org_name}</p>
                    <p className="text-xs text-muted-foreground mt-0.5">
                      {inquiry.contact_name} · {inquiry.work_email}
                    </p>
                    <p className="text-xs font-medium text-primary mt-1">{inquiry.interest}</p>
                    {inquiry.message && (
                      <p className="text-sm text-muted-foreground mt-1 whitespace-pre-wrap">{inquiry.message}</p>
                    )}
                    <p className="text-xs text-muted-foreground mt-2">{timeAgo(inquiry.created_at)}</p>
                  </div>
                  <Badge variant={STATUS_VARIANT[status]}>{INBOX_STATUS_LABELS[status]}</Badge>
                </div>

                {inquiry.admin_note && (
                  <p className="text-xs text-muted-foreground border-l-2 border-border pl-3 py-1 whitespace-pre-wrap">
                    {inquiry.admin_note}
                  </p>
                )}

                <div className="flex flex-wrap items-center gap-2 pt-1 border-t border-border">
                  {INBOX_STATUSES.map((s) => (
                    <button
                      key={s}
                      onClick={() => setInquiryStatus(inquiry.id, s)}
                      disabled={s === status}
                      className={cn(
                        'px-2.5 py-1 rounded-full text-xs border transition-colors',
                        s === status
                          ? 'bg-primary/10 text-primary border-transparent'
                          : 'border-border text-muted-foreground hover:text-foreground hover:bg-accent'
                      )}
                    >
                      {INBOX_STATUS_LABELS[s]}
                    </button>
                  ))}
                  <div className="flex-1" />
                  <Button
                    variant="ghost"
                    size="sm"
                    onClick={() =>
                      editNote(inquiry.admin_note || '', (note) => setInquiryStatus(inquiry.id, status, note))
                    }
                  >
                    <StickyNote className="w-3.5 h-3.5" /> {inquiry.admin_note ? 'Edit note' : 'Add note'}
                  </Button>
                  <Button
                    variant="ghost"
                    size="sm"
                    className="text-red-600"
                    onClick={() => {
                      if (confirm('Delete this inquiry? This cannot be undone.')) deleteInquiry(inquiry.id);
                    }}
                  >
                    <Trash2 className="w-3.5 h-3.5" />
                  </Button>
                </div>
              </Card>
            );
          })}
        </section>
      )}

      <p className="text-xs text-muted-foreground">
        Notes and statuses are internal — nothing is sent back to the person who submitted. Outbound email or SMS
        needs a server, which this project's free Firebase plan doesn't run.
      </p>
    </div>
  );
}
