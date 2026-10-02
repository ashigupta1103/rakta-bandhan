export const supportDeliveryMode = (enabled: boolean, emulator: boolean) => !enabled ? 'disabled' : emulator ? 'local-only' : 'send';

export function supportContent(body: string) {
  if (!body.trim() || body.length > 2000) throw new Error('Invalid support reply');
  const escaped = body.replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]!));
  return { subject: 'A reply from Rakta Bandhan support', text: `${body}\n\nOpen Help & support → My reports in Rakta Bandhan.`,
    html: `<p style="white-space:pre-wrap">${escaped}</p><p>Open Help &amp; support → My reports in Rakta Bandhan.</p>` };
}
