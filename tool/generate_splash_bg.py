#!/usr/bin/env python3
"""Generate the Finavig splash background — `assets/images/splash_bg.jpg`.

A custom artwork in the app's own design language (no stock photo):
  * ink -> deep-blue diagonal gradient (matches FinavigGradients.splash)
  * subtle blueprint grid
  * glowing ascending cash-flow curve with soft area fill
  * faint candlesticks + dashed gold trend line (the logo's trace gold)
  * soft radial glows, vignette and film grain

Usage:  python3 tool/generate_splash_bg.py
Requires: Pillow (pip install pillow)
"""

import math
import random
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

W, H = 1080, 1920  # portrait phone artwork
SS = 2  # supersample factor for crisp lines
W2, H2 = W * SS, H * SS

OUT = Path(__file__).resolve().parent.parent / "assets" / "images" / "splash_bg.jpg"

# ── Palette (from lib/theme/app_theme.dart) ─────────────────────────────────
INK_DEEP = (0x0B, 0x11, 0x20)
INK = (0x0F, 0x17, 0x2A)
DEEP_BLUE = (0x17, 0x25, 0x54)
BLUE = (0x3B, 0x82, 0xF6)      # accentBright
BLUE_LIGHT = (0x60, 0xA5, 0xFA)
BLUE_PALE = (0x93, 0xC5, 0xFD)
GOLD = (0xD8, 0xA8, 0x48)      # tierGold
WHITE = (0xFF, 0xFF, 0xFF)

random.seed(7)


# ── Helpers ──────────────────────────────────────────────────────────────────
def tiny_gradient(size, stops):
    """Smooth multi-stop gradient built small and upscaled (fast + smooth).

    `stops`: list of (t, (r, g, b)) sorted by t in [0, 1].
    """
    g = Image.new("RGB", (size, size))
    px = g.load()
    for y in range(size):
        for x in range(size):
            t = (x + y) / (2 * (size - 1))  # diagonal coordinate
            for i in range(len(stops) - 1):
                t0, c0 = stops[i]
                t1, c1 = stops[i + 1]
                if t0 <= t <= t1:
                    f = (t - t0) / (t1 - t0) if t1 > t0 else 0
                    px[x, y] = tuple(
                        int(c0[k] + (c1[k] - c0[k]) * f) for k in range(3)
                    )
                    break
            else:
                px[x, y] = stops[-1][1]
    return g


def radial_mask(radius, falloff=2.2):
    """Soft radial alpha mask (white center fading out) as an L-mode image."""
    size = radius * 2
    m = Image.new("L", (size, size), 0)
    px = m.load()
    step = 2
    for cy in range(0, size, step):
        for cx in range(0, size, step):
            d = math.hypot(cx - radius, cy - radius) / radius
            if d < 1.0:
                a = int(255 * ((1.0 - d) ** falloff))
                for dy in range(step):
                    for dx in range(step):
                        if cx + dx < size and cy + dy < size:
                            px[cx + dx, cy + dy] = a
    return m


def catmull_rom(points, samples_per_seg=24):
    """Smooth polyline through control points (Catmull-Rom spline)."""
    pts = [points[0]] + list(points) + [points[-1]]
    out = []
    for i in range(1, len(pts) - 2):
        p0, p1, p2, p3 = pts[i - 1], pts[i], pts[i + 1], pts[i + 2]
        for s in range(samples_per_seg):
            t = s / samples_per_seg
            t2, t3 = t * t, t * t * t
            x = 0.5 * ((2 * p1[0]) + (-p0[0] + p2[0]) * t
                       + (2 * p0[0] - 5 * p1[0] + 4 * p2[0] - p3[0]) * t2
                       + (-p0[0] + 3 * p1[0] - 3 * p2[0] + p3[0]) * t3)
            y = 0.5 * ((2 * p1[1]) + (-p0[1] + p2[1]) * t
                       + (2 * p0[1] - 5 * p1[1] + 4 * p2[1] - p3[1]) * t2
                       + (-p0[1] + 3 * p1[1] - 3 * p2[1] + p3[1]) * t3)
            out.append((x, y))
    out.append(points[-1])
    return out


def alpha_composite(base, layer):
    base.alpha_composite(layer)


# ── 1. Base diagonal gradient ────────────────────────────────────────────────
base = tiny_gradient(24, [
    (0.00, INK_DEEP),
    (0.55, INK),
    (1.00, DEEP_BLUE),
]).resize((W2, H2), Image.BICUBIC).convert("RGBA")

# ── 2. Blueprint grid ────────────────────────────────────────────────────────
grid = Image.new("RGBA", (W2, H2), (0, 0, 0, 0))
gd = ImageDraw.Draw(grid)
step = 108 * SS
for x in range(0, W2 + 1, step):
    gd.line([(x, 0), (x, H2)], fill=WHITE + (9,), width=SS)
for y in range(0, H2 + 1, step):
    gd.line([(0, y), (W2, y)], fill=WHITE + (9,), width=SS)
alpha_composite(base, grid)

# ── 3. Faint candlesticks (lower half, behind everything) ────────────────────
candles = Image.new("RGBA", (W2, H2), (0, 0, 0, 0))
cd = ImageDraw.Draw(candles)
n = 16
cw = (W2 * 0.92) / n
x = W2 * 0.04
level = H2 * 0.72
for i in range(n):
    drift = -H2 * 0.012 + random.uniform(-H2 * 0.012, H2 * 0.02)
    body_top = level + random.uniform(-H2 * 0.015, H2 * 0.005)
    body_h = random.uniform(H2 * 0.012, H2 * 0.05)
    up = drift < 0
    col = (BLUE if up else WHITE) + (20 if up else 14,)
    top, bot = body_top, body_top + body_h
    cx = x + cw * 0.5
    cd.line([(cx, top - H2 * 0.014), (cx, bot + H2 * 0.014)], fill=col, width=3 * SS)
    cd.rectangle([x + cw * 0.18, top, x + cw * 0.82, bot], fill=col)
    level += drift
    x += cw
alpha_composite(base, candles)

# ── 4. Cash-flow curve: area fill + glowing stroke ───────────────────────────
ctrl = [
    (-60, H2 * 0.70),
    (W2 * 0.16, H2 * 0.66),
    (W2 * 0.30, H2 * 0.70),
    (W2 * 0.44, H2 * 0.58),
    (W2 * 0.58, H2 * 0.62),
    (W2 * 0.74, H2 * 0.44),
    (W2 * 0.88, H2 * 0.47),
    (W2 + 60, H2 * 0.30),
]
curve = catmull_rom(ctrl)

# Soft area fill below the curve, fading to nothing at the bottom.
mask = Image.new("L", (W2, H2), 0)
md = ImageDraw.Draw(mask)
md.polygon(curve + [(W2, H2), (0, H2)], fill=255)
area_grad = tiny_gradient(16, [(0.0, BLUE + (110,)), (1.0, BLUE + (0,))])
area_grad = area_grad.resize((W2, H2), Image.BICUBIC).convert("RGBA")
# Vertical falloff: strongest right under the curve top (~y 30%) → 0 at bottom.
vfade = Image.new("L", (W2, H2), 0)
vd = ImageDraw.Draw(vfade)
top_y = min(p[1] for p in curve)
for y in range(int(top_y), H2, 4 * SS):
    t = (y - top_y) / (H2 - top_y)
    vd.line([(0, y), (W2, y)], fill=int(255 * (1 - t) ** 1.4), width=4 * SS)
area_grad.putalpha(Image.composite(vfade, Image.new("L", (W2, H2), 0), mask))
alpha_composite(base, area_grad)

# Glow layers under the stroke.
glow = Image.new("RGBA", (W2, H2), (0, 0, 0, 0))
gld = ImageDraw.Draw(glow)
for width, alpha in ((70 * SS, 22), (36 * SS, 40), (16 * SS, 70)):
    gld.line(curve, fill=BLUE_LIGHT + (alpha,), width=width, joint="curve")
glow = glow.filter(ImageFilter.GaussianBlur(18 * SS))
alpha_composite(base, glow)

# Crisp stroke.
stroke = Image.new("RGBA", (W2, H2), (0, 0, 0, 0))
sd = ImageDraw.Draw(stroke)
sd.line(curve, fill=BLUE_LIGHT + (255,), width=7 * SS, joint="curve")
alpha_composite(base, stroke)

# Data-point markers on the curve.
marks = Image.new("RGBA", (W2, H2), (0, 0, 0, 0))
mkd = ImageDraw.Draw(marks)
for t in (0.22, 0.48, 0.72):
    px_, py_ = curve[int(len(curve) * t)]
    mkd.ellipse([px_ - 9 * SS, py_ - 9 * SS, px_ + 9 * SS, py_ + 9 * SS],
                fill=BLUE_PALE + (230,))
# Final point: gold — the "target reached" accent.
fx, fy = curve[-40]
mkd.ellipse([fx - 11 * SS, fy - 11 * SS, fx + 11 * SS, fy + 11 * SS],
            fill=GOLD + (255,))
mkd.ellipse([fx - 4 * SS, fy - 4 * SS, fx + 4 * SS, fy + 4 * SS], fill=WHITE + (255,))
alpha_composite(base, marks)

# ── 5. Dashed gold trend line (subtle, above the curve) ─────────────────────
trend = Image.new("RGBA", (W2, H2), (0, 0, 0, 0))
td = ImageDraw.Draw(trend)
p_a = (0, H2 * 0.84)
p_b = (W2, H2 * 0.22)
seg = 26 * SS
gap = 20 * SS
dx, dy = p_b[0] - p_a[0], p_b[1] - p_a[1]
length = math.hypot(dx, dy)
ux, uy = dx / length, dy / length
d = 0
while d < length:
    sx, sy = p_a[0] + ux * d, p_a[1] + uy * d
    e = min(d + seg, length)
    ex, ey = p_a[0] + ux * e, p_a[1] + uy * e
    td.line([(sx, sy), (ex, ey)], fill=GOLD + (110,), width=4 * SS)
    d = e + gap
trend = trend.filter(ImageFilter.GaussianBlur(2 * SS))
alpha_composite(base, trend)

# ── 6. Radial glows ──────────────────────────────────────────────────────────
def add_glow(base, center, radius, color, strength, falloff=2.6):
    """Composite a soft radial glow of `color` at `center` onto `base`."""
    tile = Image.new("RGBA", (radius * 2, radius * 2), (0, 0, 0, 0))
    solid = Image.new("RGBA", (radius * 2, radius * 2), color + (255,))
    solid.putalpha(radial_mask(radius, falloff).point(lambda a: int(a * strength)))
    tile.alpha_composite(solid)
    # Crop to the visible region so the paste never lands off-canvas.
    x0, y0 = center[0] - radius, center[1] - radius
    cx0, cy0 = max(0, -x0), max(0, -y0)
    x1, y1 = min(W2, x0 + radius * 2), min(H2, y0 + radius * 2)
    if x1 > x0 + cx0 and y1 > y0 + cy0:
        piece = tile.crop((cx0, cy0, cx0 + (x1 - x0 - cx0), cy0 + (y1 - y0 - cy0)))
        base.alpha_composite(piece, (max(0, x0), max(0, y0)))


add_glow(base, (int(W2 * 0.82), int(H2 * 0.16)), 700 * SS, BLUE_LIGHT, 0.16)
add_glow(base, (int(W2 * 0.12), int(H2 * 0.86)), 520 * SS, GOLD, 0.10, falloff=2.8)

# ── 7. Vignette ──────────────────────────────────────────────────────────────
vig = Image.new("L", (W2, H2), 255)
vm = radial_mask(int(W2 * 1.25), falloff=1.4)
vig.paste(0, (int(W2 / 2 - W2 * 1.25), int(H2 / 2 - W2 * 1.25)), vm)
vig = vig.filter(ImageFilter.GaussianBlur(60 * SS))
dark = Image.new("RGBA", (W2, H2), INK_DEEP + (255,))
dark.putalpha(vig.point(lambda a: int((255 - a) * 0.35)))
alpha_composite(base, dark)

# ── 8. Film grain ────────────────────────────────────────────────────────────
noise = Image.effect_noise((W2, H2), 14).convert("RGB")
base = Image.blend(base, noise.convert("RGBA"), 0.028)

# ── Export ───────────────────────────────────────────────────────────────────
final = base.convert("RGB").resize((W, H), Image.LANCZOS)
OUT.parent.mkdir(parents=True, exist_ok=True)
final.save(OUT, "JPEG", quality=88, optimize=True, progressive=True)
print(f"Wrote {OUT} ({OUT.stat().st_size / 1024:.0f} KB, {W}x{H})")
