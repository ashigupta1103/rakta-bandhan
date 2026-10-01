"""Builds the public share page and its social preview image.

    python tool/make_share_page.py

Writes admin/frontend/public/app/index.html and og-image.png (1200×630).
Firebase Hosting serves it at https://rakta-bandhan2026.web.app/app/ — the
link the app shares, so WhatsApp, Instagram and X show a proper card (title,
tagline, image) instead of a bare URL. Change SITE if a custom domain is
added, and re-run tool/export_legal_html.py so the legal pages point at it.
"""
import os

from PIL import Image, ImageDraw, ImageFont

SITE = 'https://rakta-bandhan2026.web.app'
PLAY = 'https://play.google.com/store/apps/details?id=com.raktabandhan.app'
OUT = 'admin/frontend/public/app'

CREAM = (252, 248, 242)
INK = (36, 20, 19)
INK2 = (107, 83, 78)
RED = (184, 30, 20)


def font(name, size):
    for path in (f'C:/Windows/Fonts/{name}', f'/usr/share/fonts/truetype/dejavu/{name}', f'/Library/Fonts/{name}'):
        if os.path.exists(path):
            return ImageFont.truetype(path, size)
    return ImageFont.load_default(size)


def og_image():
    img = Image.new('RGB', (1200, 630), CREAM)
    d = ImageDraw.Draw(img)
    d.rectangle([0, 0, 1200, 10], fill=RED)
    logo = Image.open('assets/branding/app-icon-1024.png').convert('RGBA').resize((300, 300), Image.LANCZOS)
    img.paste(logo, (90, 165), logo)
    serif_bold = font('georgiab.ttf', 72)
    serif = font('georgia.ttf', 40)
    sans = font('arial.ttf', 30)
    d.text((450, 175), 'Rakta Bandhan', font=serif_bold, fill=INK)
    d.text((450, 275), 'Find your Bloodmate here.', font=serif, fill=RED)
    d.text((450, 330), 'Your match is a call away.', font=serif, fill=INK2)
    d.text((450, 420), 'Nearby blood donors, in minutes — a Rotary', font=sans, fill=INK2)
    d.text((450, 460), 'service project, Chennai.', font=sans, fill=INK2)
    img.save(os.path.join(OUT, 'og-image.png'), optimize=True)


PAGE = f"""<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Rakta Bandhan — find a blood donor nearby</title>
<meta name="description" content="Rakta Bandhan connects people who urgently need blood with willing, compatible donors nearby. Find your Bloodmate here.">
<meta property="og:type" content="website">
<meta property="og:site_name" content="Rakta Bandhan">
<meta property="og:url" content="{SITE}/app/">
<meta property="og:title" content="Rakta Bandhan — Find your Bloodmate here">
<meta property="og:description" content="Nearby blood donors in minutes. Your match is a call away.">
<meta property="og:image" content="{SITE}/app/og-image.png">
<meta property="og:image:width" content="1200">
<meta property="og:image:height" content="630">
<meta name="twitter:card" content="summary_large_image">
<link rel="icon" href="/legal/icon.png">
<link href="https://fonts.googleapis.com/css2?family=Barlow:wght@400;600&family=Newsreader:opsz,wght@6..72,500&display=swap" rel="stylesheet">
<style>
  :root {{ --ground:#FCF8F2; --ink:#241413; --ink2:#6B534E; --red:#B81E14; --border:#EADFCF; }}
  * {{ box-sizing: border-box; }}
  body {{ margin:0; background:var(--ground); color:var(--ink); font:16px/1.6 Barlow, system-ui, sans-serif; }}
  main {{ max-width:560px; margin:0 auto; padding:48px 20px 64px; text-align:center; }}
  img.logo {{ width:112px; height:112px; border-radius:24px; }}
  h1 {{ font:500 40px/1.15 Newsreader, Georgia, serif; margin:20px 0 8px; }}
  .tag {{ color:var(--red); font:500 22px/1.4 Newsreader, Georgia, serif; margin:0; }}
  p {{ color:var(--ink2); }}
  a.cta {{ display:inline-block; margin-top:24px; padding:14px 28px; border-radius:12px; background:var(--red); color:#fff; font-weight:600; text-decoration:none; }}
  footer {{ margin-top:48px; font-size:13px; color:var(--ink2); }}
  footer a {{ color:var(--ink2); }}
</style>
</head>
<body>
<main>
  <img class="logo" src="/legal/icon.png" alt="">
  <h1>Rakta Bandhan</h1>
  <p class="tag">Find your Bloodmate here. Your match is a call away.</p>
  <p>When someone urgently needs blood, Rakta Bandhan reaches willing, compatible donors nearby — they accept, then chat or call in the app, without sharing phone numbers publicly.</p>
  <a class="cta" href="{PLAY}">Get it on Google Play</a>
  <p style="font-size:13px;margin-top:12px">iPhone app coming soon.</p>
  <footer>
    A service project of Madras Cosmos Charitable Trust and Chennai Capital Trust, managed by Rotary Club of Madras Cosmos and Rotary Club of Chennai Capital, with support from Rotary International District 3233.<br><br>
    <a href="/legal/privacy.html">Privacy policy</a> · <a href="/legal/terms.html">Terms</a> · <a href="/legal/community-guidelines.html">Community guidelines</a> · <a href="/legal/delete-account.html">Delete your account</a>
  </footer>
</main>
</body>
</html>
"""


def main():
    os.makedirs(OUT, exist_ok=True)
    og_image()
    open(os.path.join(OUT, 'index.html'), 'w', encoding='utf-8').write(PAGE)
    print('wrote', OUT)


if __name__ == '__main__':
    main()
