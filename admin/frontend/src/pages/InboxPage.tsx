/**
 * InboxPage — every one-way submission the app can generate, triaged.
 *
 * "Report an issue" (Help & support) writes `issue_reports`; "Start a
 * conversation" (Corporate partnerships) writes `partnership_inquiries`;
 * a chat/call block-and-report (ChatService.report) writes `reports`. All
 * three are create-only for the submitter and admin-updatable per
 * firestore.rules, so triage here is a plain field write: status
 * New → In progress → Resolved, plus an internal note that only admins can
 * read. A reply goes to `support_replies` and shows up in the member's My
 * reports; partnership inquiries also carry an Email shortcut to the contact.
 * `reports` specifically has no delete in the rules (an abuse report stays
 * on record regardless of outcome), so that section has no delete button.
 */

import { useEffect, useMemo, useState } from 'react';
import {
  useIssueReports,
  usePartnershipInquiries,
  useAbuseReports,
  useAdminActions,
  useSender,
  INBOX_STATUSES,
  INBOX_STATUS_LABELS,
  fetchConversation,
  fetchStory,
  type InboxStatus,
  type AbuseReport,
  type CommunityStory,
} from '../hooks/useFirebaseData';
import { Flag, Handshake, ShieldAlert, Trash2, StickyNote, Inbox, Mail, MessagesSquare, Eye, EyeOff } from 'lucide-react';
import { Card } from '@/components/ui/card';
import { Button, buttonVariants } from '@/components/ui/button';
import { Badge } from '@/components/ui/badge';
import { cn } from '../lib/utils';
import { collection, onSnapshot, orderBy, query, where, limit, type DocumentData } from 'firebase/firestore';
import { db } from '../lib/firebase';

function ReplyBox({ source, id }: { source: string; id: string }) {
  const [body, setBody] = useState('');
  const [sent, setSent] = useState(false);
  const [replies, setReplies] = useState<string[]>([]);
  const { replyToSubmission, actionLoading, actionError } = useAdminActions();
  useEffect(() => onSnapshot(query(collection(db, 'support_replies'), where('source_collection', '==', source), where('source_id', '==', id), orderBy('created_at', 'asc'), limit(50)),
    (snapshot) => setReplies(snapshot.docs.map((d) => String(d.data().body ?? ''))), () => setReplies([])), [source, id]);
  return <div className="space-y-2 border-t border-border pt-3">
    {replies.map((reply, index) => <p key={index} className="text-sm whitespace-pre-wrap">Support: {reply}</p>)}
    <textarea aria-label="Reply to submitter" placeholder="Reply visible to the submitter" maxLength={2000} value={body}
      onChange={(e) => { setBody(e.target.value); setSent(false); }} className="w-full rounded-md border border-input bg-background p-2 text-sm" />
    <Button size="sm" disabled={actionLoading || !body.trim()} onClick={async () => {
      try { await replyToSubmission(source, id, body); setBody(''); setSent(true); } catch { /* hook displays the error */ }
    }}>Save reply</Button>
    {sent && <p className="text-sm text-muted-foreground">Reply saved in the submitter's My reports view.</p>}
    {actionError && <p className="text-sm text-destructive">{actionError}</p>}
  </div>;
}

const STATUS_VARIANT: Record<InboxStatus, 'destructive' | 'warning' | 'success'> = {
  new: 'destructive',
  in_progress: 'warning',
  resolved: 'success',
};

function statusOf(raw?: string): InboxStatus {
  return raw === 'in_progress' || raw === 'resolved' ? raw : 'new';
}

/** The chat thread behind a chat/call report, loaded only when asked for. */
function ChatContext({ report }: { report: AbuseReport }) {
  const [open, setOpen] = useState(false);
  const [lines, setLines] = useState<(DocumentData & { id: string })[] | null>(null);
  const [error, setError] = useState('');

  async function toggle() {
    setOpen(!open);
    if (open || lines) return;
    try {
      setLines(await fetchConversation(report.request_id));
    } catch {
      setError('Could not load the conversation.');
    }
  }

  const who = (uid: string) =>
    uid === report.reported_uid ? 'Reported' : uid === report.reporter_uid ? 'Reporter' : 'System';
  // Never print coordinates: a shared location is only noted, not shown.
  const text = (m: DocumentData) =>
    m.kind === 'call'
      ? `Call${m.call_seconds ? ` · ${m.call_seconds}s` : ''}`
      : m.kind === 'location'
        ? 'Shared a location'
        : String(m.text ?? '');

  return (
    <div className="space-y-2 border-t border-border pt-3">
      <Button variant="ghost" size="sm" onClick={toggle}>
        <MessagesSquare className="w-3.5 h-3.5" /> {open ? 'Hide conversation' : 'View conversation'}
      </Button>
      {open &&
        (error ? (
          <p className="text-sm text-destructive">{error}</p>
        ) : lines === null ? (
          <p className="text-sm text-muted-foreground">Loading…</p>
        ) : lines.length === 0 ? (
          <p className="text-sm text-muted-foreground">No messages on this request.</p>
        ) : (
          <div className="rounded-md border border-border p-3 space-y-1.5 max-h-72 overflow-y-auto">
            {lines.map((m) => (
              <p key={m.id} className="text-sm whitespace-pre-wrap">
                <span className={cn('font-medium', m.sender_uid === report.reported_uid && 'text-red-600')}>
                  {who(m.sender_uid)}:
                </span>{' '}
                {text(m)}
              </p>
            ))}
          </div>
        ))}
    </div>
  );
}

/** The community post behind a post report, with hide / delete right there. */
function StoryPanel({ storyId }: { storyId: string }) {
  const [story, setStory] = useState<CommunityStory | null | undefined>(undefined);
  const { setStoryHidden, deleteStory, actionLoading } = useAdminActions();
  const refresh = () => fetchStory(storyId).then(setStory).catch(() => setStory(null));

  useEffect(() => {
    let live = true;
    fetchStory(storyId)
      .then((s) => live && setStory(s))
      .catch(() => live && setStory(null));
    return () => {
      live = false;
    };
  }, [storyId]);

  return (
    <div className="space-y-2 border-t border-border pt-3">
      {story === undefined ? (
        <p className="text-sm text-muted-foreground">Loading post…</p>
      ) : story === null ? (
        <p className="text-sm text-muted-foreground">This post no longer exists.</p>
      ) : (
        <>
          <p className="text-xs text-muted-foreground">
            Reported post by {story.author_name || 'a member'}
            {story.is_hidden ? ' · currently hidden' : ''}
          </p>
          <p className="text-sm whitespace-pre-wrap rounded-md border border-border p-3">{story.body}</p>
          <div className="flex gap-2">
            <Button
              size="sm"
              variant="outline"
              disabled={actionLoading}
              onClick={async () => {
                await setStoryHidden(story.id, !story.is_hidden, story.author_name);
                refresh();
              }}
            >
              {story.is_hidden ? <Eye className="w-3.5 h-3.5" /> : <EyeOff className="w-3.5 h-3.5" />}{' '}
              {story.is_hidden ? 'Unhide post' : 'Hide post'}
            </Button>
            <Button
              size="sm"
              variant="ghost"
              className="text-red-600"
              disabled={actionLoading}
              onClick={async () => {
                if (!confirm('Delete this post? This cannot be undone.')) return;
                await deleteStory(story.id, story.author_name);
                refresh();
              }}
            >
              <Trash2 className="w-3.5 h-3.5" /> Delete post
            </Button>
          </div>
        </>
      )}
    </div>
  );
}

type Section = 'all' | 'support' | 'partnerships' | 'abuse';

/** Who sent it: the member's name and @username, looked up once per session. */
function Sender({ uid, label = 'From' }: { uid?: string; label?: string }) {
  const who = useSender(uid);
  if (!uid) return null;
  return (
    <p className="text-xs text-muted-foreground mt-0.5">
      {label} {who || '…'} <span className="font-mono opacity-60">({uid.slice(0, 6)})</span>
    </p>
  );
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
  const [section, setSection] = useState<Section>('all');
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

  const open = (items: { status?: string }[]) => items.filter((i) => statusOf(i.status) !== 'resolved').length;
  const sections: { key: Section; label: string; count: number }[] = [
    { key: 'all', label: 'All', count: unresolved },
    { key: 'support', label: 'Help & support', count: open(reports) },
    { key: 'partnerships', label: 'Partnerships', count: open(inquiries) },
    { key: 'abuse', label: 'Chat & call reports', count: open(abuseReports) },
  ];
  const show = (key: Exclude<Section, 'all'>) => section === 'all' || section === key;
  const shown =
    (show('support') ? visibleReports.length : 0) +
    (show('partnerships') ? visibleInquiries.length : 0) +
    (show('abuse') ? visibleAbuseReports.length : 0);

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
        {sections.map(({ key, label, count }) => (
          <button
            key={key}
            onClick={() => setSection(key)}
            className={cn(
              'px-3 py-1.5 rounded-full text-sm font-medium border transition-colors',
              section === key
                ? 'bg-foreground text-background border-transparent'
                : 'border-border text-muted-foreground hover:text-foreground hover:bg-accent'
            )}
          >
            {label}
            {count > 0 && <span className="ml-1.5 text-xs opacity-70">{count}</span>}
          </button>
        ))}
      </div>

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

      {!loading && shown === 0 && (
        <Card className="p-8 flex flex-col items-center gap-2 text-center">
          <Inbox className="w-6 h-6 text-muted-foreground" />
          <p className="text-sm text-muted-foreground">
            {filter === 'all'
              ? 'Nothing submitted yet. Reports from Help & support, inquiries from Corporate partnerships, and chat/call reports land here.'
              : `Nothing is ${INBOX_STATUS_LABELS[filter].toLowerCase()}.`}
          </p>
        </Card>
      )}

      {show('abuse') && visibleAbuseReports.length > 0 && (
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
                    <Sender uid={report.reporter_uid} />
                    {!report.story_id && <Sender uid={report.reported_uid} label="Reported" />}
                    <p className="text-xs text-muted-foreground font-mono mt-0.5">
                      {report.story_id
                        ? <>community post {report.story_id}</>
                        : <>reported {report.reported_uid} · request {report.request_id}</>}
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
                {report.story_id ? (
                  <StoryPanel storyId={report.story_id} />
                ) : report.request_id ? (
                  <ChatContext report={report} />
                ) : null}
                <ReplyBox source="reports" id={report.id} />
              </Card>
            );
          })}
        </section>
      )}

      {show('support') && visibleReports.length > 0 && (
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
                    <Sender uid={report.reporter_uid} />
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
                <ReplyBox source="issue_reports" id={report.id} />
              </Card>
            );
          })}
        </section>
      )}

      {show('partnerships') && visibleInquiries.length > 0 && (
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
                    <Sender uid={inquiry.requester_uid} label="Sent by member" />
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
                  <a
                    className={buttonVariants({ variant: 'ghost', size: 'sm' })}
                    href={`mailto:${encodeURIComponent(inquiry.work_email)}?subject=${encodeURIComponent(
                      `Rakta Bandhan partnership: ${inquiry.org_name}`
                    )}`}
                  >
                    <Mail className="w-3.5 h-3.5" /> Email
                  </a>
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
                <ReplyBox source="partnership_inquiries" id={inquiry.id} />
              </Card>
            );
          })}
        </section>
      )}

      <p className="text-xs text-muted-foreground">
        Notes stay internal. Replies and public triage status appear in the submitter's My reports view. Email and push delivery are pending Blaze setup.
      </p>
    </div>
  );
}
