#!/usr/bin/env python3
"""Generează wallpaper-ul și asset-urile temei (original, fără copyright).

Rulează:  python3 assets/generate_wallpaper.py
Produce:
  dotfiles/wallpapers/Pictures/wallpapers/badass-dark.png   (2560x1440)
  system/grub-theme/background.png                          (1920x1080, emblemă mai sus)
  system/plymouth/hackerlinux/logo.png                      (emblemă transparentă)

Necesită:  pip install pillow numpy
"""
import math
import os
import random

import numpy as np
from PIL import Image, ImageChops, ImageDraw, ImageFilter

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))

BG_TOP = (6, 6, 12)
BG_BOT = (20, 6, 28)
RED = (255, 46, 99)      # accent principal
CYAN = (8, 217, 214)     # accent secundar
VIOLET = (140, 60, 255)


def gradient(w, h, top, bot):
    t = np.linspace(0, 1, h)[:, None, None]
    arr = np.array(top)[None, None, :] * (1 - t) + np.array(bot)[None, None, :] * t
    arr = np.repeat(arr, w, axis=1)
    return Image.fromarray(arr.astype("uint8"), "RGB")


def perspective_grid(w, h, horizon_y, color=VIOLET):
    """Grilă în perspectivă (podea), estompată spre orizont."""
    layer = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    cx = w / 2
    # linii verticale care converg în punctul de fugă
    for i in range(-30, 31):
        x_bottom = cx + i * (w / 14)
        d.line([(cx + i * 6, horizon_y), (x_bottom, h)], fill=color + (255,), width=2)
    # linii orizontale: distanțe crescătoare spre jos
    n = 16
    for k in range(1, n + 1):
        t = (k / n) ** 2.2
        y = horizon_y + t * (h - horizon_y)
        d.line([(0, y), (w, y)], fill=color + (255,), width=2)
    # mască de opacitate: invizibil la orizont, ~35% jos
    mask = np.linspace(0, 1, h)[:, None]
    mask = np.clip((mask - horizon_y / h) / (1 - horizon_y / h), 0, 1) ** 0.9 * 0.38
    a = np.array(layer.split()[3]).astype("float32") / 255.0
    a = (a * np.repeat(mask, w, axis=1) * 255).astype("uint8")
    layer.putalpha(Image.fromarray(a, "L"))
    return layer


def emblem(size, cx, cy, r):
    """Emblemă unghiulară: hexagon întrerupt (cyan) + literă Λ ascuțită (roșu)."""
    hexl = Image.new("RGB", size, (0, 0, 0))
    lam = Image.new("RGB", size, (0, 0, 0))
    dh, dl = ImageDraw.Draw(hexl), ImageDraw.Draw(lam)

    lw = max(3, int(r * 0.045))
    pts = [(cx + r * math.cos(math.radians(-90 + 60 * k)),
            cy + r * math.sin(math.radians(-90 + 60 * k))) for k in range(6)]
    for i in range(6):
        (x1, y1), (x2, y2) = pts[i], pts[(i + 1) % 6]
        a, b = 0.10, 0.90   # lasă goluri la colțuri
        dh.line([(x1 + (x2 - x1) * a, y1 + (y2 - y1) * a),
                 (x1 + (x2 - x1) * b, y1 + (y2 - y1) * b)], fill=CYAN, width=lw)
    # hexagon interior subțire
    r2 = r * 0.82
    pts2 = [(cx + r2 * math.cos(math.radians(-90 + 60 * k)),
             cy + r2 * math.sin(math.radians(-90 + 60 * k))) for k in range(6)]
    dh.line(pts2 + [pts2[0]], fill=tuple(int(c * 0.35) for c in CYAN), width=max(1, lw // 3))

    apex = (cx, cy - 0.60 * r)
    left = (cx - 0.52 * r, cy + 0.48 * r)
    right = (cx + 0.52 * r, cy + 0.48 * r)
    leg = 0.24 * r
    poly = [apex, right, (right[0] - leg, right[1]),
            (cx, cy - 0.12 * r), (left[0] + leg, left[1]), left]
    dl.polygon(poly, fill=RED)
    # tăietură diagonală (dă agresivitate)
    dl.polygon([(cx + 0.10 * r, cy + 0.10 * r), (cx + 0.30 * r, cy + 0.10 * r),
                (cx + 0.18 * r, cy + 0.34 * r)], fill=(0, 0, 0))
    return hexl, lam


def glow(img, radii=(6, 18, 40), strength=(1.0, 0.9, 0.7)):
    out = img.copy()
    for rad, s in zip(radii, strength):
        b = img.filter(ImageFilter.GaussianBlur(rad))
        b = b.point(lambda v, s=s: min(255, int(v * s * 1.6)))
        out = ImageChops.add(out, b)
    return out


def scanlines(img, alpha=18):
    w, h = img.size
    ov = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(ov)
    for y in range(0, h, 4):
        d.line([(0, y), (w, y)], fill=(0, 0, 0, alpha), width=1)
    return Image.alpha_composite(img.convert("RGBA"), ov)


def vignette(img, strength=0.65):
    w, h = img.size
    y, x = np.ogrid[:h, :w]
    d = np.sqrt(((x - w / 2) / (w / 2)) ** 2 + ((y - h / 2) / (h / 2)) ** 2)
    m = np.clip(1 - strength * (d ** 2.2) / 1.6, 0.25, 1)[:, :, None]
    arr = np.array(img.convert("RGB")).astype("float32") * m
    return Image.fromarray(arr.astype("uint8"), "RGB")


def particles(w, h, n=140, seed=7):
    random.seed(seed)
    layer = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    for _ in range(n):
        x, y = random.randint(0, w), random.randint(0, int(h * 0.62))
        s = random.choice([1, 1, 2, 2, 3])
        c = random.choice([RED, CYAN, (200, 200, 230)])
        d.rectangle([x, y, x + s, y + s], fill=c + (random.randint(40, 140),))
    return layer


def build_wallpaper(w, h, cy_frac, r_frac, with_grid=True, with_text=True):
    base = gradient(w, h, BG_TOP, BG_BOT).convert("RGBA")
    if with_grid:
        base = Image.alpha_composite(base, perspective_grid(w, h, int(h * 0.66)))
    base = Image.alpha_composite(base, particles(w, h))

    hexl, lam = emblem((w, h), w / 2, h * cy_frac, h * r_frac)
    hexg, lamg = glow(hexl), glow(lam)
    em = ImageChops.add(hexg, lamg)
    # emblema cu glow se adaugă (screen) peste fundal
    rgb = ImageChops.screen(base.convert("RGB"), em)
    img = rgb.convert("RGBA")

    if with_text:
        d = ImageDraw.Draw(img)
        txt = "A R C H   //   X 2 7 0"
        try:
            from PIL import ImageFont
            font = ImageFont.truetype("DejaVuSansMono.ttf", int(h * 0.022))
        except OSError:
            font = None
        tw = d.textlength(txt, font=font) if font else 0
        d.text(((w - tw) / 2, h * (cy_frac + r_frac) + h * 0.05), txt,
               fill=(120, 126, 150, 200), font=font)

    img = scanlines(img)
    return vignette(img)


def build_logo(size=300):
    hexl, lam = emblem((size, size), size / 2, size / 2, size * 0.40)
    em = ImageChops.add(glow(hexl, (3, 8, 14), (0.9, 0.8, 0.6)), glow(lam, (3, 8, 14), (0.9, 0.8, 0.6)))
    arr = np.array(em).astype("float32")
    alpha = arr.max(axis=2)
    out = np.dstack([arr, alpha]).astype("uint8")
    return Image.fromarray(out, "RGBA")


def main():
    wp_dir = os.path.join(ROOT, "dotfiles/wallpapers/Pictures/wallpapers")
    os.makedirs(wp_dir, exist_ok=True)
    build_wallpaper(2560, 1440, 0.40, 0.21).convert("RGB").save(os.path.join(wp_dir, "badass-dark.png"), optimize=True)

    grub = os.path.join(ROOT, "system/grub-theme")
    os.makedirs(grub, exist_ok=True)
    build_wallpaper(1920, 1080, 0.27, 0.13, with_grid=False, with_text=False).convert("RGB").save(
        os.path.join(grub, "background.png"), optimize=True)

    ply = os.path.join(ROOT, "system/plymouth/hackerlinux")
    os.makedirs(ply, exist_ok=True)
    build_logo().save(os.path.join(ply, "logo.png"), optimize=True)
    print("OK: wallpaper, grub background, plymouth logo generate")


if __name__ == "__main__":
    main()
