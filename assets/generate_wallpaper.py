#!/usr/bin/env python3
"""Generate the theme assets: subdued cyberpunk / retro-futurist (original artwork).

Run: python3 assets/generate_wallpaper.py   (needs: pillow numpy)
Input: assets/avatar.jpg (portrait). Writes the portrait drawn in characters (wallpaper, avatar, ASCII for console/fastfetch),
the GRUB background and the Plymouth images.
"""
import math
import os
import random
import numpy as np
from PIL import Image, ImageDraw, ImageFont, ImageFilter, ImageChops

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MONO = "/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf"
MONO_B = "/usr/share/fonts/truetype/dejavu/DejaVuSansMono-Bold.ttf"

BG = (10, 12, 18)
YEL = (229, 201, 90)
TEAL = (79, 184, 196)
MAG = (196, 90, 115)
DIM = (42, 49, 66)
FG = (214, 210, 196)
MUTED = (107, 115, 133)
GLYPHS = list("0123456789ABCDEF<>/\\#%*+=-[]|")


def font(size, bold=False):
    return ImageFont.truetype(MONO_B if bold else MONO, size)


def path(*parts):
    p = os.path.join(ROOT, *parts)
    os.makedirs(os.path.dirname(p), exist_ok=True)
    return p


def save(img, *parts):
    img.save(path(*parts), optimize=True)


def glow(img, radii=(3, 10), strength=(0.7, 0.4)):
    out = img.copy()
    for r, k in zip(radii, strength):
        b = img.filter(ImageFilter.GaussianBlur(r))
        b = Image.eval(b, lambda v, k=k: int(v * k))
        out = ImageChops.screen(out, b)
    return out


def scanlines(img, alpha=34, step=3):
    ov = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(ov)
    for y in range(0, img.size[1], step):
        d.line([(0, y), (img.size[0], y)], fill=(0, 0, 0, alpha))
    return Image.alpha_composite(img.convert("RGBA"), ov).convert("RGB")


def lerp(a, b, t):
    return a + (b - a) * t


# ------------------------------------------------------------------ portrait
def portrait_luma(size):
    """Square luminance map 0..1 of the portrait with the backdrop pushed to black."""
    src = Image.open(path("assets", "avatar.jpg")).convert("L")
    w, h = src.size
    s = min(w, h)
    src = src.crop(((w - s) // 2, 0, (w - s) // 2 + s, s)).resize((size, size), Image.LANCZOS)
    a = np.array(src).astype("float32")
    a = np.clip((a - 62) / (235 - 62), 0, 1) ** 0.95        # backdrop (~30-50) -> black
    y, x = np.mgrid[0:size, 0:size] / size
    r = np.sqrt((x - 0.5) ** 2 + (y - 0.45) ** 2)
    a *= np.clip(1.35 - r * 1.6, 0, 1)                     # soft fade at the edges
    return a


def duotone(l):
    """Luma -> RGB: navy shadows, teal mids, warm yellow highlights."""
    t = l[..., None]
    lo = np.array(BG, "float32") + (np.array(TEAL, "float32") * 0.7 - np.array(BG, "float32")) * np.clip(t / 0.6, 0, 1)
    hi = np.array(TEAL, "float32") * 0.7 + (np.array(YEL, "float32") - np.array(TEAL, "float32") * 0.7) * np.clip((t - 0.6) / 0.4, 0, 1)
    rgb = np.where(t < 0.6, lo, hi)
    return Image.fromarray(np.clip(rgb, 0, 255).astype("uint8"), "RGB")


def glitch(img, seed=3, slices=3):
    """A few horizontally shifted bands + faint magenta ghost: retro-digital, kept subtle."""
    rnd = random.Random(seed)
    out = img.copy()
    w, h = img.size
    for _ in range(slices):
        y = rnd.randint(int(h * 0.2), int(h * 0.85))
        bh = rnd.randint(max(2, h // 120), max(3, h // 50))
        dx = rnd.choice([-1, 1]) * rnd.randint(w // 80, w // 35)
        band = img.crop((0, y, w, y + bh))
        out.paste(band, (dx, y))
    ghost = ImageChops.offset(img, 4, 0)
    ghost = Image.eval(ghost, lambda v: int(v * 0.18))
    tint = Image.new("RGB", img.size, MAG)
    ghost = ImageChops.multiply(ghost.convert("L").convert("RGB"), tint)
    return ImageChops.screen(out, ghost)


def portrait_image(size, seed=3):
    l = portrait_luma(size)
    img = duotone(l)
    img = glitch(img, seed)
    img = scanlines(img, 60, 3)
    return glow(img, (2, 8), (0.35, 0.25)), l


def hud_ring(size, color=YEL, width=3):
    """Segmented ring with tick marks, RGBA."""
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    m = width + 2
    for start, end in [(200, 340), (20, 70), (100, 160)]:
        d.arc([m, m, size - m, size - m], start, end, fill=color + (255,), width=width)
    d.arc([m + 10, m + 10, size - m - 10, size - m - 10], 0, 360, fill=DIM + (255,), width=1)
    for k in range(0, 360, 15):
        a = math.radians(k)
        r1, r2 = size / 2 - m - 14, size / 2 - m - (20 if k % 45 == 0 else 17)
        c = size / 2
        d.line([(c + r1 * math.cos(a), c + r1 * math.sin(a)), (c + r2 * math.cos(a), c + r2 * math.sin(a))],
               fill=(TEAL if k % 45 == 0 else DIM) + (255,), width=1)
    return img


def glyph_square(size, cols=72):
    """Glyph portrait centred on a square dark canvas."""
    g = glyph_portrait(cols=cols, cell=14, noise=False)
    g = Image.eval(g, lambda v: min(255, int(v * 1.7)))      # small sizes need more punch
    # centre on the HEAD (upper part of the silhouette), not on head+neck: the head is tilted
    # to the upper left, so anything else leaves the face off-centre. The neck runs out at the bottom.
    a = np.array(g.convert("L")).astype("float32")
    ys, xs = np.where(a > 90)
    if len(xs):
        y0, y1 = ys.min(), ys.max()
        head = ys < y0 + (y1 - y0) * 0.5
        hx, hy, wgt = xs[head], ys[head], a[ys[head], xs[head]]
        cx, cy = np.average(hx, weights=wgt), np.average(hy, weights=wgt)
        half = np.percentile(np.hypot(hx - cx, hy - cy), 98) * 1.30
        cy += half * 0.10                                   # head sits a little above centre
        g = g.crop((int(cx - half), int(cy - half), int(cx + half), int(cy + half)))
    sc = size * 0.92 / max(g.size)
    g = g.resize((int(g.width * sc), int(g.height * sc)), Image.LANCZOS)
    img = Image.new("RGB", (size, size), BG)
    paste_screen(img, g, ((size - g.width) // 2, (size - g.height) // 2))
    return scanlines(img, 40, 3)


def avatar_round(size):
    """Portrait in a circle with a HUD ring, RGBA (for Plymouth)."""
    inner = int(size * 0.80)
    img = glyph_square(inner, cols=56)
    mask = Image.new("L", (inner, inner), 0)
    ImageDraw.Draw(mask).ellipse([0, 0, inner - 1, inner - 1], fill=255)
    mask = mask.filter(ImageFilter.GaussianBlur(2))
    out = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    out.paste(img, ((size - inner) // 2, (size - inner) // 2), mask)
    return Image.alpha_composite(out, hud_ring(size))


# ------------------------------------------------------------------ glyph portrait
CHARSET = " .,:;-=+*/\\|()[]{}<>!?17ijtfrxnuvczXYUJCLQ0OZmwqpdbkhao#MW&8%B@"


def glyph_ramp(f):
    """CHARSET sorted by ink coverage in font f (light -> dense)."""
    cov = []
    for ch in dict.fromkeys(CHARSET):
        im = Image.new("L", (40, 60), 0)
        ImageDraw.Draw(im).text((4, 4), ch, font=f, fill=255)
        cov.append((np.array(im).mean(), ch))
    cov.sort()
    return [c for _, c in cov]


def face_square(l):
    """Square crop centred on the face (upper part of the lit area), padded with black."""
    m = l > 0.15
    ys, xs = np.where(m)
    if not len(ys):
        return l
    y0, y1 = ys.min(), ys.max()
    band = m[y0:y0 + int((y1 - y0) * 0.5)]
    by, bx = np.where(band)
    cy, cx = y0 + by.mean(), bx.mean()
    side = int((bx.max() - bx.min()) * 1.45)
    half = side // 2
    pad = np.pad(l, half, mode="constant")
    cy, cx = int(cy) + half, int(cx) + half
    return pad[cy - half:cy + half, cx - half:cx + half]


def face_luma(res=512, square=False):
    """Portrait luma cropped to head and neck, contrast boosted, with edges so dark
    features (glasses, hair line) still get outlines."""
    l = portrait_luma(res)
    src = Image.open(path("assets", "avatar.jpg")).convert("L")
    w0, h0 = src.size
    s0 = min(w0, h0)
    src = src.crop(((w0 - s0) // 2, 0, (w0 - s0) // 2 + s0, s0)).resize((res, res), Image.LANCZOS)
    e = np.array(src.filter(ImageFilter.GaussianBlur(1.2)).filter(ImageFilter.FIND_EDGES)).astype("float32") / 255
    e = np.clip(e * 5, 0, 1)
    halo = np.array(Image.fromarray((np.clip(l * 4, 0, 1) * 255).astype("uint8")).filter(ImageFilter.MaxFilter(15))).astype("float32") / 255
    l = np.maximum(l, e * 0.6 * halo)
    k = res / 512
    l = face_square(l) if square else l[int(20 * k):int(470 * k), int(80 * k):int(480 * k)]
    # equalize the lit area so highlights keep detail instead of turning into one flat block
    m = l > 0.05
    if m.any():
        ranks = l[m].argsort().argsort().astype("float32") / max(1, m.sum() - 1)
        l = l.copy()
        l[m] = 0.12 + 0.88 * (0.5 * ranks + 0.5 * l[m])
    return l


def glyph_grid(cols, aspect=0.5, square=False):
    """Luma sampled on a character grid (aspect = cell width / cell height)."""
    l = face_luma(square=square)
    h, w = l.shape
    rows = max(1, int(cols * (h / w) * aspect))
    img = Image.fromarray((l * 255).astype("uint8")).resize((cols, rows), Image.LANCZOS)
    return np.array(img).astype("float32") / 255


def tone(v):
    """Luma -> colour along teal -> yellow, dim in the shadows."""
    t = np.clip((v - 0.15) / 0.85, 0, 1)
    if t < 0.55:
        k = t / 0.55
        return tuple(int(lerp(c * 0.35, c, k)) for c in TEAL)
    k = (t - 0.55) / 0.45
    return tuple(int(lerp(a, b, k)) for a, b in zip(TEAL, YEL))


def glyph_portrait(cols, cell, seed=4, noise=True, square=False):
    """Portrait drawn only with characters, RGB on black."""
    f = font(cell)
    ramp = glyph_ramp(f)
    probe = ImageDraw.Draw(Image.new("RGB", (8, 8)))
    cw = probe.textlength("M", font=f)
    ch = cell * 1.18
    g = glyph_grid(cols, aspect=cw / ch, square=square)
    rows = g.shape[0]
    img = Image.new("RGB", (int(cols * cw) + 4, int(rows * ch) + 4), (0, 0, 0))
    d = ImageDraw.Draw(img)
    rnd = random.Random(seed)
    for r in range(rows):
        for c in range(cols):
            v = g[r, c]
            if v < 0.06:
                if noise and rnd.random() < 0.012:                       # sparse noise in the dark
                    d.text((c * cw, r * ch), rnd.choice("01:."), font=f, fill=DIM)
                continue
            idx = min(len(ramp) - 1, int(v ** 0.9 * len(ramp)))
            d.text((c * cw, r * ch), ramp[idx], font=f, fill=tone(v ** 0.75))
    return glow(img, (2, 6), (0.45, 0.25))


def dedent(lines):
    """Drop the common leading blank columns so the art starts at the left edge."""
    ind = min((len(l) - len(l.lstrip(" ")) for l in lines if l.strip()), default=0)
    return [l[ind:] for l in lines]


def ascii_portrait(cols=44):
    """Plain ASCII portrait for the Linux console."""
    g = glyph_grid(cols, aspect=0.5)
    ramp = " .:-=+*#%@"
    lines = ["".join(ramp[min(len(ramp) - 1, int(v ** 0.85 * len(ramp)))] for v in row).rstrip() for row in g]
    while lines and not lines[0].strip():
        lines.pop(0)
    while lines and not lines[-1].strip():
        lines.pop()
    return "\n".join(dedent(lines)) + "\n"


def fastfetch_logo(cols=42):
    """Coloured ASCII portrait for fastfetch ($1 yellow, $2 cyan, $3 dim blue)."""
    g = glyph_grid(cols, aspect=0.5)
    ramp = " .'`^,:;Il!i><~+_-?][}{1)(|/tfjrxnuvczXYUJCLQ0OZmwqpdbkhao*#MW&8%B@"
    out = []
    for row in g:
        line, cur = "", None
        for v in row:
            if v < 0.06:
                line += " "
                continue
            col = "$1" if v > 0.7 else "$2" if v > 0.3 else "$3"
            if col != cur:
                line += col
                cur = col
            line += ramp[min(len(ramp) - 1, int(v ** 0.9 * len(ramp)))]
        out.append(line.rstrip())
    while out and not out[0].strip():
        out.pop(0)
    while out and not out[-1].strip():
        out.pop()
    return "\n".join(dedent(out)) + "\n"


# ------------------------------------------------------------------ backgrounds
def backdrop(w, h, grid=True, seed=1):
    """Navy gradient, faint horizon glow and a perspective grid floor."""
    y = np.linspace(0, 1, h)[:, None]
    top = np.array((12, 14, 22), "float32")
    bot = np.array((8, 9, 14), "float32")
    base = (top + (bot - top) * y)[:, None, :]
    horizon = 0.62
    glowband = np.exp(-((y - horizon) ** 2) / 0.004)[..., None]
    base = base + glowband * (np.array(MAG, "float32") * 0.10)
    img = Image.fromarray(np.broadcast_to(base, (h, w, 3)).astype("uint8").copy(), "RGB")
    if grid:
        layer = Image.new("RGB", (w, h), (0, 0, 0))
        d = ImageDraw.Draw(layer)
        hy = int(h * horizon)
        vx = w / 2
        for i in range(-24, 25):
            d.line([(vx + i * w * 0.012, hy), (vx + i * w * 0.16, h)], fill=tuple(int(c * 0.35) for c in TEAL))
        k = 1.0
        yy = hy + 4
        while yy < h:
            d.line([(0, yy), (w, yy)], fill=tuple(int(c * 0.30) for c in TEAL))
            k *= 1.28
            yy = hy + int(4 * k)
        fade = np.clip((np.arange(h) - hy) / (h - hy), 0, 1) ** 1.3
        arr = np.array(layer).astype("float32") * fade[:, None, None]
        img = ImageChops.screen(img, glow(Image.fromarray(arr.astype("uint8")), (2,), (0.6,)))
    return img


def data_columns(w, h, seed=5, density=0.10, cell=20):
    """Sparse dim data streams on the left/right edges."""
    rnd = random.Random(seed)
    layer = Image.new("RGB", (w, h), (0, 0, 0))
    d = ImageDraw.Draw(layer)
    f = font(int(cell * 0.8))
    for c in range(w // cell):
        x = c * cell
        edge = min(x, w - x) / (w / 2)
        if edge > 0.22 or rnd.random() > density * 3:
            continue
        head = rnd.randint(0, h // cell)
        length = rnd.randint(4, 14)
        for i in range(length):
            r = head - i
            if r < 0:
                continue
            t = (1 - i / length) ** 1.8 * 0.55
            d.text((x, r * cell), rnd.choice(GLYPHS), font=f, fill=tuple(int(cc * t) for cc in TEAL))
    return layer


def hud_frame(img, label_left, label_right):
    """Thin corner brackets + small labels."""
    w, h = img.size
    d = ImageDraw.Draw(img)
    m, L = int(w * 0.025), int(w * 0.04)
    col = tuple(int(c * 0.8) for c in YEL)
    for (x, y, sx, sy) in [(m, m, 1, 1), (w - m, m, -1, 1), (m, h - m, 1, -1), (w - m, h - m, -1, -1)]:
        d.line([(x, y), (x + sx * L, y)], fill=col, width=2)
        d.line([(x, y), (x, y + sy * L)], fill=col, width=2)
    f = font(max(12, h // 70))
    d.text((m + 8, h - m - h // 40), label_left, font=f, fill=MUTED)
    d.text((w - m - 8, h - m - h // 40), label_right, font=f, fill=MUTED, anchor="ra")
    return img


def paste_screen(base, layer, xy):
    box = (xy[0], xy[1], xy[0] + layer.width, xy[1] + layer.height)
    base.paste(ImageChops.screen(base.crop(box), layer), box)


def wallpaper_avatar(w, h):
    img = backdrop(w, h)
    img = ImageChops.screen(img, data_columns(w, h))
    por = glyph_portrait(cols=180, cell=max(8, h // 150))
    scale = (h * 0.86) / por.height
    por = por.resize((int(por.width * scale), int(por.height * scale)), Image.LANCZOS)
    paste_screen(img, por, (int(w * 0.64 - por.width / 2), int(h * 0.06)))
    f = font(int(h * 0.075), True)
    title = Image.new("RGB", (int(w * 0.45), int(h * 0.12)), (0, 0, 0))
    ImageDraw.Draw(title).text((0, 0), "ARCH // X270", font=f, fill=YEL)
    title = scanlines(glow(title, (3, 10), (0.6, 0.35)), 70, 3)
    paste_screen(img, title, (int(w * 0.07), int(h * 0.36)))
    sub = font(int(h * 0.022))
    d = ImageDraw.Draw(img)
    d.text((int(w * 0.07), int(h * 0.36) + int(h * 0.10)), "HYPRLAND  ·  KEYBOARD-FIRST  ·  NETRUNNER", font=sub, fill=TEAL)
    d.line([(int(w * 0.07), int(h * 0.36) - 14), (int(w * 0.07) + int(w * 0.18), int(h * 0.36) - 14)], fill=MAG, width=2)
    hud_frame(img, "SYS://ARCH  HYPRLAND", "THINKPAD X270  ·  NODE 01")
    return scanlines(img, 22, 3)


def wallpaper_city(w, h, seed=11):
    """Retro-futurist skyline: striped sun, layered towers with lit windows, grid floor."""
    rnd = random.Random(seed)
    img = backdrop(w, h)
    horizon = int(h * 0.62)
    d = ImageDraw.Draw(img)
    # stars
    for _ in range(140):
        x, y = rnd.randrange(w), rnd.randrange(int(h * 0.5))
        v = rnd.randint(40, 110)
        d.point((x, y), fill=(v, v, int(v * 1.1)))
    # striped sun: yellow -> magenta, subdued
    r = int(h * 0.20)
    cx, cy = int(w * 0.5), horizon - int(r * 0.72)
    pad = r // 2
    sun = Image.new("RGB", (2 * r + 2 * pad, 2 * r + 2 * pad), (0, 0, 0))
    sd = ImageDraw.Draw(sun)
    stripe = max(3, r // 20)
    for yy in range(2 * r):
        t = yy / (2 * r)
        col = tuple(int(lerp(a, b, t) * 0.75) for a, b in zip(YEL, MAG))
        half = int(math.sqrt(max(0, r * r - (yy - r) ** 2)))
        gap = t > 0.5 and (yy // stripe) % 3 == 0
        if not gap and cy - r + yy < horizon:
            sd.line([(pad + r - half, pad + yy), (pad + r + half, pad + yy)], fill=col)
    sun = glow(sun, (8, 30), (0.35, 0.25))
    paste_screen(img, sun, (cx - r - pad, cy - r - pad))
    # skyline layers (far -> near)
    for layer, (base_h, col, win_p) in enumerate([(0.20, (24, 28, 44), 0.03), (0.26, (16, 19, 30), 0.05), (0.30, (8, 9, 15), 0.07)]):
        x = -rnd.randint(0, 60)
        while x < w:
            bw = rnd.randint(int(w * 0.018), int(w * 0.055))
            near_sun = abs((x + bw / 2) - cx) < r * 1.3
            bh = int(h * base_h * rnd.uniform(0.3, 1.0) * (0.3 if near_sun else 1))
            top = horizon - bh
            d.rectangle([x, top, x + bw, horizon], fill=col)
            if rnd.random() < 0.25:                                    # antenna
                d.line([(x + bw // 2, top), (x + bw // 2, top - rnd.randint(8, 30))], fill=col, width=2)
            for wy in range(top + 6, horizon - 4, 9):
                for wx in range(x + 4, x + bw - 4, 7):
                    if rnd.random() < win_p:
                        c = rnd.choice([YEL, TEAL, TEAL, MAG])
                        k = 0.35 + 0.35 * (layer / 2)
                        d.rectangle([wx, wy, wx + 2, wy + 3], fill=tuple(int(v * k) for v in c))
            x += bw + rnd.randint(0, 6)
    # neon edge on the horizon
    d.line([(0, horizon), (w, horizon)], fill=tuple(int(c * 0.6) for c in MAG), width=2)
    img = ImageChops.screen(img, data_columns(w, h, seed=13, density=0.05))
    hud_frame(img, "SYS://ARCH  HYPRLAND", "THINKPAD X270  ·  NIGHT CITY")
    return scanlines(img, 24, 3)


def wallpaper_grid(w, h, label=True):
    img = backdrop(w, h)
    img = ImageChops.screen(img, data_columns(w, h, seed=9, density=0.07))
    if label:
        f = font(int(h * 0.11), True)
        t = Image.new("RGB", (w, int(h * 0.16)), (0, 0, 0))
        ImageDraw.Draw(t).text((w // 2, int(h * 0.08)), "ARCH", font=f, fill=YEL, anchor="mm")
        t = scanlines(glow(t, (3, 12), (0.6, 0.35)), 80, 3)
        paste_screen(img, t, (0, int(h * 0.36)))
        hud_frame(img, "SYS://ARCH  HYPRLAND", "THINKPAD X270")
    return scanlines(img, 22, 3)


# ------------------------------------------------------------------ plymouth
def text_img(segments, size, pad=4):
    f = font(size)
    probe = ImageDraw.Draw(Image.new("RGB", (10, 10)))
    widths = [probe.textlength(t, font=f) for t, _ in segments]
    w, h = int(sum(widths)) + pad * 2, int(size * 1.5)
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    x = pad
    for (t, c), tw in zip(segments, widths):
        d.text((x, pad // 2), t, font=f, fill=c + (255,))
        x += tw
    return img


def to_rgba_on_black(img):
    a = np.array(img).astype("float32")
    alpha = a.max(axis=2)
    rgb = np.where(alpha[..., None] > 0, a / np.maximum(alpha[..., None], 1) * 255, 0)
    return Image.fromarray(np.dstack([rgb, alpha]).astype("uint8"), "RGBA")


def plymouth_assets():
    out = ("system", "plymouth", "hackerlinux")
    logo = avatar_round(240)
    save(logo, *out, "logo.png")
    a = np.array(logo).astype("float32")
    ghost = np.zeros_like(a)
    ghost[..., 0], ghost[..., 1], ghost[..., 2] = MAG[0], MAG[1], MAG[2]
    ghost[..., 3] = a[..., 3] * (a[..., :3].mean(axis=2) / 255) * 0.9
    save(Image.fromarray(ghost.astype("uint8"), "RGBA"), *out, "logo_ghost.png")
    bar = Image.new("RGBA", (180, 4), (0, 0, 0, 0))
    d = ImageDraw.Draw(bar)
    d.rectangle([0, 0, 120, 3], fill=TEAL + (200,))
    d.rectangle([126, 0, 179, 3], fill=YEL + (200,))
    save(bar, *out, "glitch_bar.png")
    save(text_img([("A R C H  //  X 2 7 0", YEL)], 18), *out, "title.png")
    cell = 20
    for i in range(4):
        rnd = random.Random(100 + i)
        h = rnd.choice([360, 480, 600, 720])
        strip = Image.new("RGB", (cell, h), (0, 0, 0))
        d = ImageDraw.Draw(strip)
        f = font(int(cell * 0.8))
        rows = h // cell
        for r in range(rows):
            k = ((r + 1) / rows) ** 2.2
            col = YEL if r == rows - 1 else tuple(int(c * k * 0.8) for c in TEAL)
            d.text((2, r * cell), rnd.choice(GLYPHS), font=f, fill=col)
        save(to_rgba_on_black(strip), *out, f"rain{i}.png")

    def row(tag, name, val, done=True):
        dots = " " + "." * (22 - len(name)) + " "
        c1, c2 = (YEL, (150, 190, 200)) if done else (MUTED, MUTED)
        return [(tag, c1), (" " + name + dots + val, c2)]

    lines = [
        row("[ OK ]", "kernel", "loaded"),
        row("[ OK ]", "initramfs", "ready"),
        row("[ OK ]", "root volume", "mounted"),
        row("[ OK ]", "services", "starting"),
        row("[ .. ]", "session", "pending", False),
    ]
    for i, segs in enumerate(lines):
        save(text_img(segs, 20), *out, f"line{i}.png")
    save(text_img([("LUKS passphrase> ", YEL)], 22), *out, "prompt.png")
    save(text_img([("*", TEAL)], 22, pad=1), *out, "star.png")
    save(text_img([("> ", MUTED), ("type the passphrase, then Enter", MUTED)], 18), *out, "hint.png")
    bar = Image.new("RGBA", (360, 14), (0, 0, 0, 0))
    ImageDraw.Draw(bar).rectangle([0, 0, 359, 13], outline=DIM + (255,), width=1)
    save(bar, *out, "bar_bg.png")
    save(Image.new("RGBA", (4, 8), YEL + (255,)), *out, "bar_fill.png")
    panel = Image.new("RGBA", (580, 300), BG + (225,))
    d = ImageDraw.Draw(panel)
    d.rectangle([0, 0, 579, 299], outline=DIM + (255,), width=1)
    d.line([(0, 0), (60, 0)], fill=YEL + (255,), width=2)
    d.line([(519, 299), (579, 299)], fill=TEAL + (255,), width=2)
    save(panel, *out, "panel.png")


def main():
    wp = ("dotfiles", "wallpapers", "Pictures", "wallpapers")
    save(wallpaper_city(2560, 1440), *wp, "cyber-city.png")
    save(wallpaper_grid(2560, 1440), *wp, "cyber-grid.png")
    save(wallpaper_grid(2560, 1440, label=False), *wp, "cyber-clean.png")
    save(wallpaper_city(1920, 1080), "system", "grub-theme", "background.png")

    save(glyph_square(512), "dotfiles", "hypr", ".config", "hypr", "avatar.png")
    with open(path("assets", "avatar.txt"), "w") as f:
        f.write(ascii_portrait())
    with open(path("dotfiles", "fastfetch", ".config", "fastfetch", "logo.txt"), "w") as f:
        f.write(fastfetch_logo())
    plymouth_assets()

    # optional ThinkPad custom boot logo (flash with Lenovo's BIOS update tool, see README)
    logo = avatar_round(200)
    canvas = Image.new("RGB", (384, 216), (0, 0, 0))
    canvas.paste(logo, ((384 - 200) // 2, 8), logo)
    canvas.convert("P", palette=Image.ADAPTIVE, colors=64).save(path("assets", "bios-logo.gif"))


if __name__ == "__main__":
    main()
