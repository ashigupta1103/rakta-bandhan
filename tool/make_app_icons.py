"""Generates store-ready app icons from the approved logo.

The full lockup (wordmark + Rotary wheel + ECG line) is illegible at
launcher sizes, so the icon uses the logo's own symbol — the droplet with
the interlocked heart — unchanged, isolated from the rest of the artwork by
position + colour. Run from the repo root:  python tool/make_app_icons.py

Outputs:
  android/app/src/main/res/mipmap-*/ic_launcher.png            (legacy)
  android/app/src/main/res/mipmap-*/ic_launcher_foreground.png  (adaptive)
  android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml
  android/app/src/main/res/values/ic_launcher_background.xml
  ios/Runner/Assets.xcassets/AppIcon.appiconset/*.png  (opaque, per Contents.json)
  web/icons/*.png, web/favicon.png
  assets/branding/app-icon-1024.png  (Play Store 512 is derived from this)
"""
import json
import os

from PIL import Image

SRC = 'assets/branding/final-logo-transparent.png'
BG = (252, 248, 242, 255)  # AppColors.warmGround #FCF8F2
S = 2.08  # the source is 4160px; coordinates below were measured on a 2000px view


def extract_mark() -> Image.Image:
    """The droplet + interlocked heart, exactly as drawn in the logo.

    The logo is a handful of separate opaque shapes: the droplet, the heart
    (whose white outline also carries its petals and the ECG line), the
    Rotary wheel, and the wordmark. Keep the two shapes under the seed
    points below; then cut the ECG line off where it leaves the heart's
    lower-right edge (measured: x = 1038 - (y - 1100), 2000px view).
    """
    from collections import deque

    from PIL import ImageFilter

    im = Image.open(SRC).convert('RGBA')
    q = 4
    small = im.resize((im.width // q, im.height // q), Image.BILINEAR)
    alpha = small.getchannel('A').load()
    w, h = small.size

    def ecg(dx, dy):
        return dx > 1150 or (dy >= 1232 and dx > 1038 - (dy - 1100) + 1)

    keep = bytearray(w * h)
    for seed in ((835, 500), (800, 1100)):  # droplet body, heart centre
        sx, sy = int(seed[0] * S / q), int(seed[1] * S / q)
        keep[sy * w + sx] = 1
        todo = deque([(sx, sy)])
        while todo:
            x, y = todo.popleft()
            for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
                if (0 <= nx < w and 0 <= ny < h and not keep[ny * w + nx] and alpha[nx, ny] > 40
                        and not ecg(nx * q / S, ny * q / S)):
                    keep[ny * w + nx] = 1
                    todo.append((nx, ny))

    mask = Image.frombytes('L', (w, h), bytes(v * 255 for v in keep))
    mask = mask.filter(ImageFilter.MaxFilter(3)).resize(im.size, Image.NEAREST)
    # Re-apply the cut at full resolution so the heart's edge stays crisp.
    mpx = mask.load()
    for y in range(int(1240 * S), int(1300 * S)):
        for x in range(int(840 * S), int(1160 * S)):
            if ecg(x / S, y / S):
                mpx[x, y] = 0
    out = Image.new('RGBA', im.size, (0, 0, 0, 0))
    out.paste(im, (0, 0), mask)
    # The mask only chooses *which* shapes; the original anti-aliasing stays.
    return out.crop(out.getbbox())


def fit(mark: Image.Image, size: int, fill: float, bg=BG) -> Image.Image:
    """mark centred on a square canvas, its longest side = fill * size."""
    canvas = Image.new('RGBA', (size, size), bg)
    scale = fill * size / max(mark.size)
    m = mark.resize((max(1, round(mark.width * scale)), max(1, round(mark.height * scale))), Image.LANCZOS)
    # Optical centring: the droplet's mass sits low (the heart), nudge up 2%.
    canvas.alpha_composite(m, ((size - m.width) // 2, (size - m.height) // 2 - round(size * 0.02)))
    return canvas


def main():
    mark = extract_mark()
    master = fit(mark, 1024, 0.70)
    master.convert('RGB').save('assets/branding/app-icon-1024.png')

    # iOS — opaque, sizes from Contents.json.
    ios_dir = 'ios/Runner/Assets.xcassets/AppIcon.appiconset'
    for img in json.load(open(os.path.join(ios_dir, 'Contents.json')))['images']:
        pt = float(img['size'].split('x')[0])
        px = round(pt * int(img['scale'][0]))
        master.resize((px, px), Image.LANCZOS).convert('RGB').save(os.path.join(ios_dir, img['filename']))

    # Android legacy + adaptive (foreground inside the 66% safe zone).
    dens = {'mdpi': 1, 'hdpi': 1.5, 'xhdpi': 2, 'xxhdpi': 3, 'xxxhdpi': 4}
    fg = fit(mark, 432, 0.50, bg=(0, 0, 0, 0))
    for d, k in dens.items():
        out = f'android/app/src/main/res/mipmap-{d}'
        os.makedirs(out, exist_ok=True)
        master.resize((round(48 * k),) * 2, Image.LANCZOS).save(f'{out}/ic_launcher.png')
        fg.resize((round(108 * k),) * 2, Image.LANCZOS).save(f'{out}/ic_launcher_foreground.png')
    os.makedirs('android/app/src/main/res/mipmap-anydpi-v26', exist_ok=True)
    open('android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml', 'w').write(
        '<?xml version="1.0" encoding="utf-8"?>\n'
        '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
        '    <background android:drawable="@color/ic_launcher_background"/>\n'
        '    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>\n'
        '</adaptive-icon>\n')
    open('android/app/src/main/res/values/ic_launcher_background.xml', 'w').write(
        '<?xml version="1.0" encoding="utf-8"?>\n<resources>\n'
        '    <color name="ic_launcher_background">#FCF8F2</color>\n</resources>\n')

    # Web / PWA.
    for name, size, fill in [('Icon-192', 192, 0.70), ('Icon-512', 512, 0.70),
                             ('Icon-maskable-192', 192, 0.52), ('Icon-maskable-512', 512, 0.52)]:
        fit(mark, size, fill).convert('RGB').save(f'web/icons/{name}.png')
    fit(mark, 64, 0.80).save('web/favicon.png')
    print('icons written; mark size', mark.size)


if __name__ == '__main__':
    main()
