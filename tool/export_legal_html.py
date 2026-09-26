"""Publishes the in-app legal text as static web pages for the store listings.

Both stores require public URLs: a privacy policy (App Store + Play) and an
account-deletion page (Play's "Delete account URL"). The text is read from
lib/legal/legal_documents.dart + legal_config.dart — the same source the app
renders — so the web and in-app copies cannot drift. Re-run after editing
either file:

    python tool/export_legal_html.py

Output goes to admin/frontend/public/legal/, which Vite copies into the
Firebase Hosting build (firebase.json → admin/frontend/build):
    https://<project>.web.app/legal/privacy.html
    https://<project>.web.app/legal/terms.html
    https://<project>.web.app/legal/delete-account.html
"""
import html
import os
import re

SRC = 'lib/legal/legal_documents.dart'
CFG = 'lib/legal/legal_config.dart'
OUT = 'admin/frontend/public/legal'


def dart_strings(chunk: str):
    """Single-quoted Dart string literals (with \\' escapes) in order."""
    return [m.group(1).replace("\\'", "'") for m in re.finditer(r"'((?:[^'\\]|\\.)*)'", chunk)]


def load_config():
    cfg = {}
    for m in re.finditer(r"const (k\w+) = (?:'((?:[^'\\]|\\.)*)'|(true|false));", open(CFG, encoding='utf-8').read()):
        cfg[m.group(1)] = m.group(2) if m.group(2) is not None else m.group(3) == 'true'
    return cfg


def interpolate(text: str, cfg) -> str:
    return re.sub(r'\$(k\w+)', lambda m: str(cfg.get(m.group(1), m.group(0))), text)


def parse_doc(src: str, name: str, cfg):
    start = src.index(f'const {name} = LegalDocument(')
    end = src.index('\n);', start)
    body = src[start:end]
    title = dart_strings(body[body.index('title:'):])[0]
    intro_part = body[body.index('intro:'):body.index('summary:')]
    intro = ''.join(dart_strings(intro_part))
    summary = dart_strings(body[body.index('summary: ['):body.index('sections: [')])
    sections = []
    for m in re.finditer(r"LegalSection\('(\w+)', '((?:[^'\\]|\\.)*)', \[(.*?)\]\),", body, re.S):
        sections.append((m.group(1), m.group(2).replace("\\'", "'"), dart_strings(m.group(3))))
    f = lambda t: html.escape(interpolate(t, cfg))
    return {
        'title': f(title),
        'intro': f(intro),
        'summary': [f(s) for s in summary],
        'sections': [(i, f(h), [f(line) for line in lines]) for i, h, lines in sections],
    }


PAGE = """<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{title} — Rakta Bandhan</title>
<meta name="description" content="{description}">
<link rel="icon" href="/legal/icon.png">
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link href="https://fonts.googleapis.com/css2?family=Barlow:wght@400;500;600&family=Newsreader:opsz,wght@6..72,500;6..72,600&display=swap" rel="stylesheet">
<style>
  :root {{ --ground:#FCF8F2; --ink:#241413; --ink2:#6B534E; --muted:#A2908A; --red:#B81E14; --border:#EADFCF; --divider:#F2E9DC; --sand:#F5EDE1; --gold-tint:#FBF0D9; --gold-deep:#63410B; }}
  * {{ box-sizing: border-box; }}
  body {{ margin:0; background:var(--ground); color:var(--ink); font:16px/1.65 Barlow, system-ui, sans-serif; }}
  main {{ max-width: 680px; margin: 0 auto; padding: 40px 20px 72px; }}
  .brand {{ display:flex; align-items:center; gap:10px; color:var(--red); font-weight:600; font-size:14px; text-decoration:none; }}
  .brand img {{ width:28px; height:28px; border-radius:7px; }}
  h1 {{ font-family: Newsreader, Georgia, serif; font-weight:600; font-size: clamp(32px, 7vw, 44px); line-height:1.1; margin: 14px 0 8px; }}
  h2 {{ font-family: Newsreader, Georgia, serif; font-weight:600; font-size: 24px; line-height:1.2; margin: 6px 0 8px; }}
  .meta {{ color:var(--ink2); font-size:14px; font-variant-numeric: tabular-nums; }}
  .draft {{ background:var(--gold-tint); color:var(--gold-deep); border-radius:10px; padding:10px 14px; font-size:14px; margin-top:16px; }}
  .short {{ background:#fff; border:1px solid var(--border); border-radius:16px; padding:18px 20px 8px; margin:24px 0 8px; }}
  .short h2 {{ font-size: 20px; margin:0 0 6px; }}
  .short li {{ margin: 0 0 8px; }}
  nav ol {{ padding-left: 22px; color: var(--ink2); }}
  nav a {{ color: var(--ink); text-decoration: none; }}
  nav a:hover {{ text-decoration: underline; text-decoration-color: var(--red); }}
  section {{ border-top:1px solid var(--divider); margin-top:28px; padding-top:22px; }}
  .num {{ color:var(--red); font-size:13px; font-weight:600; font-variant-numeric: tabular-nums; }}
  section ul {{ padding-left: 20px; }}
  section li::marker {{ color: var(--red); }}
  .contact {{ background:var(--sand); border-radius:16px; padding:18px 20px; margin-top:36px; }}
  .steps li {{ margin-bottom: 10px; }}
  footer {{ margin-top:36px; color:var(--muted); font-size:13px; }}
  footer a {{ color: var(--ink2); }}
</style>
</head>
<body>
<main>
  <a class="brand" href="/legal/privacy.html"><img src="/legal/icon.png" alt="">Rakta Bandhan</a>
  {body}
  <footer>
    <a href="/legal/privacy.html">Privacy policy</a> ·
    <a href="/legal/terms.html">Terms of use</a> ·
    <a href="/legal/delete-account.html">Delete your account</a>
  </footer>
</main>
</body>
</html>
"""


def contact_block(cfg):
    lines = [f"<p><strong>{html.escape(cfg['kLegalEntity'])}</strong> · {html.escape(cfg['kLegalCity'])}</p>"]
    if cfg.get('kGrievanceOfficerName'):
        lines.append(f"<p>Grievance Officer: {html.escape(cfg['kGrievanceOfficerName'])}</p>")
    if cfg.get('kLegalContactEmail'):
        e = html.escape(cfg['kLegalContactEmail'])
        lines.append(f'<p>Email <a href="mailto:{e}">{e}</a>. We reply within 30 days, and sooner for account or safety issues.</p>')
    else:
        lines.append('<p>A contact address and Grievance Officer will be listed here before public launch.</p>')
    return '<div class="contact"><h2>Questions, requests or complaints</h2>' + ''.join(lines) + '</div>'


def render_doc(doc, cfg):
    parts = [f"<h1>{doc['title']}</h1>",
             f"<p class=\"meta\">Version {cfg['kLegalVersion']} · Effective {cfg['kLegalEffectiveDate']}</p>"]
    if not cfg['kLegalApproved']:
        parts.append('<p class="draft">Draft awaiting legal review. It describes how the app works today, but is not yet the final, approved text.</p>')
    parts.append(f"<p>{doc['intro']}</p>")
    parts.append('<div class="short"><h2>In short</h2><ul>' + ''.join(f'<li>{p}</li>' for p in doc['summary']) + '</ul></div>')
    parts.append('<nav aria-label="Contents"><h2>Contents</h2><ol>' +
                 ''.join(f'<li><a href="#{i}">{h}</a></li>' for i, h, _ in doc['sections']) + '</ol></nav>')
    for n, (i, h, lines) in enumerate(doc['sections'], 1):
        out, bullets = [], []
        for line in lines:
            if line.startswith('- '):
                bullets.append(f'<li>{line[2:]}</li>')
                continue
            if bullets:
                out.append('<ul>' + ''.join(bullets) + '</ul>')
                bullets = []
            out.append(f'<p>{line}</p>')
        if bullets:
            out.append('<ul>' + ''.join(bullets) + '</ul>')
        parts.append(f'<section id="{i}"><div class="num">{n:02d}</div><h2>{h}</h2>{"".join(out)}</section>')
    parts.append(contact_block(cfg))
    return '\n  '.join(parts)


def render_delete(cfg):
    email = cfg.get('kLegalContactEmail')
    ask = (f'Email <a href="mailto:{html.escape(email)}?subject=Delete%20my%20Rakta%20Bandhan%20account">{html.escape(email)}</a> '
           'from any address, with the subject “Delete my Rakta Bandhan account” and the mobile number you registered with. '
           'We confirm by calling or messaging that number, then delete within 7 days.'
           if email else 'A contact address for deletion requests will be listed here before public launch.')
    return f"""<h1>Delete your account</h1>
  <p class="meta">Rakta Bandhan · {html.escape(cfg['kLegalEntity'])}</p>
  <h2>In the app — immediate</h2>
  <ol class="steps">
    <li>Open Rakta Bandhan and go to <strong>My Page</strong>.</li>
    <li>Tap <strong>Settings</strong>.</li>
    <li>Scroll to <strong>Delete account</strong>, tap <strong>Delete my account</strong>, and confirm.</li>
  </ol>
  <h2>What is deleted</h2>
  <ul>
    <li>Your profile: name, phone number, blood group, location and availability.</li>
    <li>Your public donor listing and any ID photo you submitted.</li>
    <li>Every chat message you sent.</li>
    <li>Your sign-in account.</li>
  </ul>
  <h2>What happens to shared records</h2>
  <ul>
    <li>Requests you raised that are still open are cancelled, and your name and number are removed from them.</li>
    <li>A request you had accepted as a donor goes back to other donors.</li>
    <li>A record that a donation took place is kept without anything that identifies you.</li>
    <li>Analytics data is kept according to Firebase Analytics retention settings, up to 14 months, and is not linked to your name or number.</li>
  </ul>
  <h2>Can’t open the app?</h2>
  <p>{ask}</p>"""


def main():
    cfg = load_config()
    src = open(SRC, encoding='utf-8').read()
    os.makedirs(OUT, exist_ok=True)
    for name, fname, desc in [('privacyPolicy', 'privacy.html', 'How Rakta Bandhan collects, uses and protects your data.'),
                              ('termsOfUse', 'terms.html', 'The terms for using Rakta Bandhan.')]:
        doc = parse_doc(src, name, cfg)
        assert doc['sections'], f'no sections parsed for {name}'
        open(os.path.join(OUT, fname), 'w', encoding='utf-8').write(
            PAGE.format(title=doc['title'], description=desc, body=render_doc(doc, cfg)))
        print(fname, len(doc['sections']), 'sections')
    open(os.path.join(OUT, 'delete-account.html'), 'w', encoding='utf-8').write(
        PAGE.format(title='Delete your account', description='How to delete your Rakta Bandhan account and data.', body=render_delete(cfg)))
    from PIL import Image
    Image.open('assets/branding/app-icon-1024.png').resize((96, 96), Image.LANCZOS).save(os.path.join(OUT, 'icon.png'))
    print('delete-account.html, icon.png')


if __name__ == '__main__':
    main()
