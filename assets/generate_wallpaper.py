#!/usr/bin/env python3
"""Generate the matrix-terminal theme assets (original artwork).

Run: python3 assets/generate_wallpaper.py   (needs: pillow numpy)
Writes wallpapers, the GRUB background and the Plymouth images.
"""
import os
import random
import numpy as np
from PIL import Image, ImageDraw, ImageFont, ImageFilter, ImageChops

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MONO = "/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf"
MONO_B = "/usr/share/fonts/truetype/dejavu/DejaVuSansMono-Bold.ttf"
BG = (2, 10, 5)
GREEN = (57, 255, 122)
MID = (34, 211, 107)
DIM = (15, 90, 45)
GLYPHS = list("0123456789ABCDEF{}<>/\\$#%@*+=-[]|")


def font(size, bold=False):
    return ImageFont.truetype(MONO_B if bold else MONO, size)


def glow(img, radii=(4, 12, 30), strength=(1.0, 0.8, 0.6)):
    """Screen-blend blurred copies of an RGB image on top of itself."""
    out = img.copy()
    for r, k in zip(radii, strength):
        b = img.filter(ImageFilter.GaussianBlur(r))
        b = Image.eval(b, lambda v, k=k: int(v * k))
        out = ImageChops.screen(out, b)
    return out


def rain_layer(w, h, cell=22, seed=1, density=0.85, head_bright=True):
    """RGB image (black bg) of falling-glyph columns with bright heads and fading trails."""
    rnd = random.Random(seed)
    img = Image.new("RGB", (w, h), (0, 0, 0))
    d = ImageDraw.Draw(img)
    f = font(int(cell * 0.85))
    cols = w // cell
    rows = h // cell
    for c in range(cols):
        if rnd.random() > density:
            continue
        head = rnd.randint(2, rows + 12)
        length = rnd.randint(6, 26)
        for i in range(length):
            r = head - i
            if r < 0 or r >= rows:
                continue
            t = 1 - i / length
            if i == 0 and head_bright:
                col = (200, 255, 215)
            else:
                k = t ** 1.6
                col = (int(GREEN[0] * k * 0.45), int(GREEN[1] * k), int(GREEN[2] * k * 0.7))
            d.text((c * cell + 2, r * cell), rnd.choice(GLYPHS), font=f, fill=col)
    return img


def vignette(img, center_dim=0.0, edge=0.55):
    w, h = img.size
    y, x = np.mgrid[0:h, 0:w]
    r = np.sqrt(((x - w / 2) / (w / 2)) ** 2 + ((y - h / 2) / (h / 2)) ** 2)
    m = np.clip(1 - edge * r ** 2, 0.25, 1.0)
    if center_dim:
        m = m * (1 - center_dim * np.exp(-(r ** 2) * 3))
    a = np.array(img).astype("float32") * m[..., None]
    return Image.fromarray(a.astype("uint8"), "RGB")


def scanlines(img, alpha=40):
    w, h = img.size
    ov = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(ov)
    for y in range(0, h, 3):
        d.line([(0, y), (w, y)], fill=(0, 0, 0, alpha), width=1)
    return Image.alpha_composite(img.convert("RGBA"), ov).convert("RGB")


def wordmark(text, size, stripe=3):
    """Striped block wordmark with a green shadow, returned as RGB on black."""
    f = font(size, True)
    probe = ImageDraw.Draw(Image.new("RGB", (10, 10)))
    bbox = probe.textbbox((0, 0), text, font=f)
    tw, th = bbox[2] - bbox[0], bbox[3] - bbox[1]
    pad = size // 3
    w, h = tw + pad * 2, th + pad * 2
    base = Image.new("RGB", (w, h), (0, 0, 0))
    d = ImageDraw.Draw(base)
    d.text((pad - bbox[0] + 6, pad - bbox[1] + 6), text, font=f, fill=DIM)         # shadow
    d.text((pad - bbox[0], pad - bbox[1]), text, font=f, fill=GREEN)
    arr = np.array(base).astype("float32")
    arr[::stripe] *= 0.45                                                          # scan stripes
    return glow(Image.fromarray(arr.astype("uint8"), "RGB"), (3, 10), (0.9, 0.6))


def paste_screen(base, layer, xy):
    """Screen-blend layer onto base at xy (both RGB)."""
    box = (xy[0], xy[1], xy[0] + layer.width, xy[1] + layer.height)
    region = base.crop(box)
    base.paste(ImageChops.screen(region, layer), box)


def to_rgba_on_black(img):
    """RGB-on-black -> RGBA where brightness becomes alpha (for Plymouth sprites)."""
    a = np.array(img).astype("float32")
    alpha = a.max(axis=2)
    rgb = np.where(alpha[..., None] > 0, a / np.maximum(alpha[..., None], 1) * 255, 0)
    return Image.fromarray(np.dstack([rgb, alpha]).astype("uint8"), "RGBA")


def wallpaper(w, h, with_logo, seed, rain=True):
    base = Image.new("RGB", (w, h), BG)
    if rain:
        layer = rain_layer(w, h, cell=max(18, w // 110), seed=seed)
        base = ImageChops.screen(base, glow(layer, (2, 8), (0.8, 0.5)))
    base = vignette(base, center_dim=0.55 if (with_logo and rain) else 0.0)
    if with_logo:
        wm = wordmark("ARCH", int(h * 0.22))
        paste_screen(base, wm, ((w - wm.width) // 2, int(h * 0.30)))
        sub = Image.new("RGB", (w, 60), (0, 0, 0))
        ImageDraw.Draw(sub).text((w // 2, 30), "H Y P R L A N D   ·   X 2 7 0", font=font(int(h * 0.022)),
                                 fill=MID, anchor="mm")
        paste_screen(base, glow(sub, (3,), (0.8,)), (0, int(h * 0.30) + wm.height + 10))
    return scanlines(base)


def save(img, *parts):
    path = os.path.join(ROOT, *parts)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img.save(path, optimize=True)


def text_img(segments, size, pad=4):
    """Render [(text, color), ...] on one line to an RGBA image."""
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


def plymouth_assets():
    out = ("system", "plymouth", "hackerlinux")
    wm = wordmark("ARCH", 150)
    save(to_rgba_on_black(wm), *out, "logo.png")
    # rain strips: one column wide, tall; head at the bottom
    cell = 20
    for i in range(4):
        rnd = random.Random(100 + i)
        h = rnd.choice([520, 640, 760, 900])
        strip = Image.new("RGB", (cell, h), (0, 0, 0))
        d = ImageDraw.Draw(strip)
        f = font(int(cell * 0.85))
        rows = h // cell
        for r in range(rows):
            t = (r + 1) / rows
            k = t ** 2.2
            col = (200, 255, 215) if r == rows - 1 else (int(57 * k * 0.5), int(255 * k), int(122 * k * 0.7))
            d.text((2, r * cell), rnd.choice(GLYPHS), font=f, fill=col)
        save(to_rgba_on_black(strip), *out, f"rain{i}.png")
    ok = GREEN
    mid = (95, 190, 125)
    def row(tag, name, val, done=True):
        dots = " " + "." * (22 - len(name)) + " "
        c1, c2 = (ok, mid) if done else (DIM, (60, 130, 85))
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
    save(text_img([("LUKS passphrase> ", GREEN)], 22), *out, "prompt.png")
    save(text_img([("*", (200, 255, 215))], 22, pad=1), *out, "star.png")
    save(text_img([("> ", MID), ("type the passphrase, then Enter", mid)], 18), *out, "hint.png")
    bar = Image.new("RGBA", (360, 14), (0, 0, 0, 0))
    ImageDraw.Draw(bar).rectangle([0, 0, 359, 13], outline=MID + (255,), width=1)
    save(bar, *out, "bar_bg.png")
    save(Image.new("RGBA", (4, 8), GREEN + (255,)), *out, "bar_fill.png")
    panel = Image.new("RGBA", (580, 300), (2, 10, 5, 215))
    ImageDraw.Draw(panel).rectangle([0, 0, 579, 299], outline=DIM + (255,), width=1)
    save(panel, *out, "panel.png")


def main():
    save(wallpaper(2560, 1440, True, 7), "dotfiles", "wallpapers", "Pictures", "wallpapers", "matrix-logo.png")
    save(wallpaper(2560, 1440, False, 11), "dotfiles", "wallpapers", "Pictures", "wallpapers", "matrix-rain.png")
    save(wallpaper(2560, 1440, True, 0, rain=False), "dotfiles", "wallpapers", "Pictures", "wallpapers", "matrix-clean.png")
    g = wallpaper(1920, 1080, True, 3)
    save(g, "system", "grub-theme", "background.png")
    plymouth_assets()


if __name__ == "__main__":
    main()
