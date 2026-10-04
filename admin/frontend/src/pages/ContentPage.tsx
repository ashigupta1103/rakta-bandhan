/**
 * ContentPage — everything the app shows on its non-transactional screens,
 * editable here so none of it is hardcoded copy any more:
 *
 *  · What's New        → `announcements`, Community → What's New
 *  · Testimonials      → `testimonials`, More → Testimonials
 *  · Impact counter    → `public_stats/impact`, Community → Impact
 *  · Community stories → member posts; hide (reversible) or delete
 *
 * `announcements` and `testimonials` are admin-write-only per
 * firestore.rules. A member can offer a testimonial from the app, but it only
 * lands in the private `testimonial_submissions` queue; an admin approves it
 * here (publish as-is or edit first) or rejects it, so nothing reaches the
 * Testimonials page without a review.
 */

import { useState } from 'react';
import {
  useAnnouncements,
  useTestimonials,
  useTestimonialSubmissions,
  useCommunityStories,
  useImpactCounter,
  useAdminActions,
  type Announcement,
  type Testimonial,
  type TestimonialSubmission,
} from '../hooks/useFirebaseData';
import { Plus, Trash2, Pencil, Megaphone, Quote, Droplet, MessagesSquare, Eye, EyeOff, Check, X } from 'lucide-react';
import { Card } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Badge } from '@/components/ui/badge';
import { Input } from '@/components/ui/input';

function timeAgo(ts?: { toDate: () => Date }) {
  if (!ts) return '';
  const days = Math.floor((Date.now() - ts.toDate().getTime()) / 86400000);
  if (days < 1) return 'today';
  if (days < 30) return `${days}d ago`;
  return `${Math.floor(days / 30)}mo ago`;
}

const textareaClass =
  'w-full rounded-md border border-input bg-background px-3 py-2 text-sm placeholder:text-muted-foreground focus-visible:outline-none focus-visible:ring-1 focus-visible:ring-ring';

export default function ContentPage() {
  const { announcements, loading: announcementsLoading } = useAnnouncements();
  const { testimonials, loading: testimonialsLoading } = useTestimonials();
  const { submissions } = useTestimonialSubmissions();
  const { stories, loading: storiesLoading } = useCommunityStories();
  const { count: impactCount } = useImpactCounter();
  const {
    actionError,
    saveAnnouncement,
    deleteAnnouncement,
    saveTestimonial,
    deleteTestimonial,
    approveTestimonialSubmission,
    rejectTestimonialSubmission,
    setImpactCount,
    setStoryHidden,
    deleteStory,
  } = useAdminActions();

  const [announcementForm, setAnnouncementForm] = useState<{ id?: string; title: string; body: string } | null>(null);
  const [testimonialForm, setTestimonialForm] = useState<{
    id?: string;
    submissionId?: string;
    author_uid?: string;
    quote: string;
    name: string;
    username: string;
    role: string;
  } | null>(null);
  const [impactDraft, setImpactDraft] = useState('');
  const [formError, setFormError] = useState('');

  async function submitAnnouncement(e: React.FormEvent) {
    e.preventDefault();
    if (!announcementForm) return;
    if (!announcementForm.title.trim() || !announcementForm.body.trim()) {
      setFormError('Title and body are both required.');
      return;
    }
    setFormError('');
    await saveAnnouncement(announcementForm);
    setAnnouncementForm(null);
  }

  async function submitTestimonial(e: React.FormEvent) {
    e.preventDefault();
    if (!testimonialForm) return;
    if (!testimonialForm.quote.trim()) {
      setFormError('The quote is required.');
      return;
    }
    setFormError('');
    if (testimonialForm.submissionId) {
      await approveTestimonialSubmission(testimonialForm.submissionId, testimonialForm);
    } else {
      await saveTestimonial(testimonialForm);
    }
    setTestimonialForm(null);
  }

  async function submitImpact(e: React.FormEvent) {
    e.preventDefault();
    const next = Number.parseInt(impactDraft.trim(), 10);
    if (Number.isNaN(next) || next < 0) {
      setFormError('Enter a whole number, 0 or more.');
      return;
    }
    setFormError('');
    await setImpactCount(next);
    setImpactDraft('');
  }

  return (
    <div className="p-6 space-y-8">
      <div>
        <h1 className="text-xl font-semibold">Content</h1>
        <p className="text-sm text-muted-foreground mt-0.5">
          What the app shows on Community, What&apos;s New, Impact and Testimonials.
        </p>
      </div>

      {(actionError || formError) && (
        <Card className="p-3 text-sm text-red-600 border-red-500/40">{formError || actionError}</Card>
      )}

      {/* ── What's New ──────────────────────────────────────────────────── */}
      <section className="space-y-3">
        <div className="flex items-center justify-between">
          <div>
            <h2 className="flex items-center gap-2 text-sm font-semibold">
              <Megaphone className="w-4 h-4" /> What&apos;s New
            </h2>
            <p className="text-xs text-muted-foreground mt-0.5">
              {announcementsLoading ? '…' : `${announcements.length} live in Community → What's New`}
            </p>
          </div>
          <Button size="sm" onClick={() => setAnnouncementForm({ title: '', body: '' })}>
            <Plus className="w-4 h-4" /> New
          </Button>
        </div>

        {announcementForm && (
          <Card className="p-4">
            <form onSubmit={submitAnnouncement} className="space-y-3">
              <Input
                placeholder="Title"
                value={announcementForm.title}
                onChange={(e) => setAnnouncementForm({ ...announcementForm, title: e.target.value })}
              />
              <textarea
                className={textareaClass}
                rows={4}
                placeholder="Body — camp, drive or initiative details"
                value={announcementForm.body}
                onChange={(e) => setAnnouncementForm({ ...announcementForm, body: e.target.value })}
              />
              <div className="flex gap-2">
                <Button type="submit" size="sm">
                  {announcementForm.id ? 'Save changes' : 'Publish'}
                </Button>
                <Button type="button" size="sm" variant="outline" onClick={() => setAnnouncementForm(null)}>
                  Cancel
                </Button>
              </div>
            </form>
          </Card>
        )}

        {!announcementsLoading && announcements.length === 0 && (
          <Card className="p-4 text-sm text-muted-foreground">
            Nothing published — the app&apos;s What&apos;s New tab shows its empty state.
          </Card>
        )}

        {announcements.map((a: Announcement) => (
          <Card key={a.id} className="p-4">
            <div className="flex items-start gap-3">
              <div className="min-w-0 flex-1">
                <p className="text-sm font-medium">{a.title}</p>
                <p className="text-sm text-muted-foreground mt-1 whitespace-pre-wrap">{a.body}</p>
                <p className="text-xs text-muted-foreground mt-2">{timeAgo(a.created_at)}</p>
              </div>
              <div className="flex gap-1">
                <Button
                  variant="ghost"
                  size="sm"
                  onClick={() => setAnnouncementForm({ id: a.id, title: a.title, body: a.body })}
                >
                  <Pencil className="w-3.5 h-3.5" />
                </Button>
                <Button
                  variant="ghost"
                  size="sm"
                  className="text-red-600"
                  onClick={() => {
                    if (confirm(`Delete "${a.title}"? This cannot be undone.`)) deleteAnnouncement(a.id, a.title);
                  }}
                >
                  <Trash2 className="w-3.5 h-3.5" />
                </Button>
              </div>
            </div>
          </Card>
        ))}
      </section>

      {/* ── Testimonials ────────────────────────────────────────────────── */}
      <section className="space-y-3">
        <div className="flex items-center justify-between">
          <div>
            <h2 className="flex items-center gap-2 text-sm font-semibold">
              <Quote className="w-4 h-4" /> Testimonials
            </h2>
            <p className="text-xs text-muted-foreground mt-0.5">
              {testimonialsLoading ? '…' : `${testimonials.length} live behind More → Testimonials`}
            </p>
          </div>
          <Button size="sm" onClick={() => setTestimonialForm({ quote: '', name: '', username: '', role: '' })}>
            <Plus className="w-4 h-4" /> New
          </Button>
        </div>

        <Card className="p-3 text-xs text-amber-600 border-amber-500/40">
          The app shows a testimonial under the member&apos;s @username only, never their registered name. Quotes members
          send from the app arrive below with their consent to publish. A quote you add yourself needs the person&apos;s
          written permission, and shows as &ldquo;Rakta Bandhan community&rdquo; unless you give it a username.
        </Card>

        {testimonialForm && (
          <Card className="p-4">
            <form onSubmit={submitTestimonial} className="space-y-3">
              <textarea
                className={textareaClass}
                rows={4}
                placeholder="Quote"
                value={testimonialForm.quote}
                onChange={(e) => setTestimonialForm({ ...testimonialForm, quote: e.target.value })}
              />
              <Input
                placeholder="Name (internal, never shown in the app)"
                value={testimonialForm.name}
                onChange={(e) => setTestimonialForm({ ...testimonialForm, name: e.target.value })}
              />
              <Input
                placeholder="Public @username (optional)"
                value={testimonialForm.username}
                onChange={(e) => setTestimonialForm({ ...testimonialForm, username: e.target.value })}
              />
              <Input
                placeholder="Role (e.g. Donor, Hospital coordinator)"
                value={testimonialForm.role}
                onChange={(e) => setTestimonialForm({ ...testimonialForm, role: e.target.value })}
              />
              <div className="flex gap-2">
                <Button type="submit" size="sm">
                  {testimonialForm.id ? 'Save changes' : 'Publish'}
                </Button>
                <Button type="button" size="sm" variant="outline" onClick={() => setTestimonialForm(null)}>
                  Cancel
                </Button>
              </div>
            </form>
          </Card>
        )}

        {submissions.length > 0 && (
          <div className="space-y-2">
            <h3 className="flex items-center gap-2 text-xs font-semibold text-muted-foreground">
              Awaiting review <Badge variant="warning">{submissions.length}</Badge>
            </h3>
            {submissions.map((s: TestimonialSubmission) => {
              const fields = {
                quote: s.quote,
                name: s.name || '',
                username: s.username || '',
                role: s.role || '',
                author_uid: s.author_uid,
              };
              return (
                <Card key={s.id} className="p-4 space-y-3 border-amber-500/40">
                  <p className="text-sm italic whitespace-pre-wrap">&ldquo;{s.quote}&rdquo;</p>
                  <p className="text-xs text-muted-foreground">
                    Will appear as {s.username ? `@${s.username}` : 'Rakta Bandhan community'}
                    {s.role ? ` · ${s.role}` : ''} · {timeAgo(s.created_at)} · from {s.name || 'a member'} · agreed to publish
                  </p>
                  <div className="flex flex-wrap gap-2 pt-1 border-t border-border">
                    <Button
                      size="sm"
                      onClick={() => approveTestimonialSubmission(s.id, fields)}
                    >
                      <Check className="w-3.5 h-3.5" /> Approve and publish
                    </Button>
                    <Button
                      size="sm"
                      variant="outline"
                      onClick={() => setTestimonialForm({ ...fields, submissionId: s.id })}
                    >
                      <Pencil className="w-3.5 h-3.5" /> Edit first
                    </Button>
                    <Button
                      size="sm"
                      variant="ghost"
                      className="text-red-600"
                      onClick={() => {
                        if (confirm(`Reject the testimonial from ${s.name || 'this member'}? It will be deleted.`))
                          rejectTestimonialSubmission(s.id, s.name);
                      }}
                    >
                      <X className="w-3.5 h-3.5" /> Reject
                    </Button>
                  </div>
                </Card>
              );
            })}
          </div>
        )}

        {!testimonialsLoading && testimonials.length === 0 && (
          <Card className="p-4 text-sm text-muted-foreground">
            Nothing published — the Testimonials page shows its empty state.
          </Card>
        )}

        {testimonials.map((t: Testimonial) => (
          <Card key={t.id} className="p-4">
            <div className="flex items-start gap-3">
              <div className="min-w-0 flex-1">
                <p className="text-sm italic">&ldquo;{t.quote}&rdquo;</p>
                <p className="text-xs text-muted-foreground mt-2">
                  {t.username ? `@${t.username}` : 'Rakta Bandhan community'}
                  {t.role ? ` · ${t.role}` : ''} · {timeAgo(t.created_at)}
                  {t.name ? ` · ${t.name} (internal)` : ''}
                </p>
              </div>
              <div className="flex gap-1">
                <Button
                  variant="ghost"
                  size="sm"
                  onClick={() =>
                    setTestimonialForm({ id: t.id, quote: t.quote, name: t.name, username: t.username || '', role: t.role || '' })
                  }
                >
                  <Pencil className="w-3.5 h-3.5" />
                </Button>
                <Button
                  variant="ghost"
                  size="sm"
                  className="text-red-600"
                  onClick={() => {
                    if (confirm('Delete this testimonial? This cannot be undone.'))
                      deleteTestimonial(t.id, t.name);
                  }}
                >
                  <Trash2 className="w-3.5 h-3.5" />
                </Button>
              </div>
            </div>
          </Card>
        ))}
      </section>

      {/* ── Impact counter ──────────────────────────────────────────────── */}
      <section className="space-y-3">
        <div>
          <h2 className="flex items-center gap-2 text-sm font-semibold">
            <Droplet className="w-4 h-4" /> Impact counter
          </h2>
          <p className="text-xs text-muted-foreground mt-0.5">Community → Impact, this month</p>
        </div>
        <Card className="p-4">
          <div className="flex flex-wrap items-end gap-4">
            <div>
              <p className="text-3xl font-semibold tabular-nums">{impactCount ?? '—'}</p>
              <p className="text-xs text-muted-foreground mt-1">
                donations this month · +1 per confirmed donation, automatically
              </p>
            </div>
            <div className="flex-1" />
            <form onSubmit={submitImpact} className="flex items-center gap-2">
              <Input
                className="w-28"
                inputMode="numeric"
                placeholder={String(impactCount ?? 0)}
                value={impactDraft}
                onChange={(e) => setImpactDraft(e.target.value)}
              />
              <Button type="submit" size="sm" variant="outline" disabled={!impactDraft.trim()}>
                Correct
              </Button>
            </form>
          </div>
          <p className="text-xs text-muted-foreground mt-3">
            Setting this overrides the figure outright — use it for a miscount, or for donations confirmed outside the
            app. Confirmed donations keep adding +1 on top of whatever you set.
          </p>
        </Card>
      </section>

      {/* ── Community stories ───────────────────────────────────────────── */}
      <section className="space-y-3">
        <div>
          <h2 className="flex items-center gap-2 text-sm font-semibold">
            <MessagesSquare className="w-4 h-4" /> Community stories
          </h2>
          <p className="text-xs text-muted-foreground mt-0.5">
            {storiesLoading
              ? '…'
              : `${stories.length} posted by members · ${stories.filter((s) => s.is_hidden).length} hidden`}
          </p>
        </div>

        {!storiesLoading && stories.length === 0 && (
          <Card className="p-4 text-sm text-muted-foreground">No stories posted yet.</Card>
        )}

        {stories.map((s) => (
          <Card key={s.id} className={s.is_hidden ? 'p-4 bg-muted/40' : 'p-4'}>
            <div className="flex items-start gap-3">
              <div className="min-w-0 flex-1">
                <div className="flex items-center gap-2">
                  <p className="text-sm font-medium">
                    {s.author_name || 'A donor'}
                    {s.topic ? ` · ${s.topic}` : ''}
                  </p>
                  {s.is_hidden && <Badge variant="warning">Hidden</Badge>}
                </div>
                <p className="text-sm text-muted-foreground mt-1 whitespace-pre-wrap">{s.body}</p>
                <p className="text-xs text-muted-foreground mt-2">{timeAgo(s.created_at)}</p>
              </div>
              <div className="flex gap-1">
                <Button
                  variant="ghost"
                  size="sm"
                  onClick={() => setStoryHidden(s.id, !s.is_hidden, s.author_name)}
                >
                  {s.is_hidden ? <Eye className="w-3.5 h-3.5" /> : <EyeOff className="w-3.5 h-3.5" />}
                </Button>
                <Button
                  variant="ghost"
                  size="sm"
                  className="text-red-600"
                  onClick={() => {
                    if (confirm('Delete this story? This cannot be undone — hiding it is reversible.'))
                      deleteStory(s.id, s.author_name);
                  }}
                >
                  <Trash2 className="w-3.5 h-3.5" />
                </Button>
              </div>
            </div>
          </Card>
        ))}
      </section>
    </div>
  );
}
