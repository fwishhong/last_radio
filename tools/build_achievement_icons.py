"""
build_achievement_icons.py
Renders the 8 Last Radio achievement icons (unlocked + locked, 64x64 each)
plus 16 .png.import sidecars. Stylized Pillow primitives only — no AI gen
in this environment, but the brief permits the geometric-primitive fallback.

Palette (sober, muted per docs/LAST_RADIO_V2_DESIGN.md):
  - lantern_yellow   #E8B25C   (warm flame)
  - lantern_glow     #F4D58A   (halo)
  - rust_orange      #B5633A   (rust, sunset, dawn glow)
  - teal_dark        #2F4A4A   (radio, antenna, signal lines)
  - teal_mid         #4A6B6B
  - storm_blue       #3B5266
  - ash_gray         #4A4642   (silhouette, wood, paper)
  - ash_gray_dark    #2D2A28
  - paper            #C8B894   (door, padlock, radio body)
  - paper_dark       #8A7B5A
  - skin             #7A5A40   (Nora, Elias hint)
  - sky_dawn         #D08A55   (horizon, sunrise)
  - sky_dawn_pale    #E0A878

Locked variant = luminance (grayscale) + alpha *= 0.55 + slight darken.
"""
from __future__ import annotations

import math
import os
import random
import struct
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------
ROOT = Path(r"C:\Users\Administrator\Desktop\codex\last_radio v2")
OUT_DIR = ROOT / "assets" / "final" / "achievements"
OUT_DIR.mkdir(parents=True, exist_ok=True)

PNG_SIZE = 64
BAKE_SIZE = 256  # render at 256 then downscale to 64 with LANCZOS

# Color palette
C = {
    "lantern_yellow":  (232, 178,  92),
    "lantern_glow":    (244, 213, 138),
    "rust_orange":     (181,  99,  58),
    "rust_dark":       (122,  68,  40),
    "teal_dark":       ( 47,  74,  74),
    "teal_mid":        ( 74, 107, 107),
    "teal_signal":     ( 96, 156, 140),
    "storm_blue":      ( 59,  82, 102),
    "ash_gray":        ( 74,  70,  66),
    "ash_gray_dark":   ( 45,  42,  40),
    "ash_gray_light":  (110, 104,  96),
    "paper":           (200, 184, 148),
    "paper_dark":      (138, 123,  90),
    "skin":            (122,  90,  64),
    "skin_dark":       ( 82,  60,  44),
    "sky_dawn":        (208, 138,  85),
    "sky_dawn_pale":   (224, 168, 120),
    "sky_dawn_soft":   (180, 130,  95),
    "white_warm":      (240, 226, 198),
    "black":           (  0,   0,   0),
}

# ---------------------------------------------------------------------------
# Per-icon renderers
# Each takes a BAKE_SIZE x BAKE_SIZE RGBA Image, draws on it, returns it.
# Subject guidance drawn from the brief; rendering stays sober and graphic.
# ---------------------------------------------------------------------------
def _new_canvas() -> Image.Image:
    img = Image.new("RGBA", (BAKE_SIZE, BAKE_SIZE), (0, 0, 0, 0))
    return img


def _fill_bg(d: ImageDraw.ImageDraw, color, alpha=255):
    """Subtle square background panel (rounded-corner feel via no rounding
    here — transparency does the work in Godot). Used only as a soft tint."""
    d.rectangle([(0, 0), (BAKE_SIZE, BAKE_SIZE)], fill=(*color, alpha))


def _draw_corner_vignette(img: Image.Image, color, alpha=42):
    """Apply a soft radial-ish darkening at corners for depth."""
    overlay = Image.new("RGBA", img.size, (0, 0, 0, 0))
    od = ImageDraw.Draw(overlay)
    od.ellipse([(-120, -120), (BAKE_SIZE + 120, BAKE_SIZE + 120)],
               fill=(*color, alpha))
    overlay = overlay.filter(ImageFilter.GaussianBlur(radius=60))
    img.alpha_composite(overlay)


def _soft_glow(img: Image.Image, center, radius, color, alpha=110):
    """Place a soft radial glow at a point."""
    overlay = Image.new("RGBA", img.size, (0, 0, 0, 0))
    od = ImageDraw.Draw(overlay)
    cx, cy = center
    od.ellipse([(cx - radius, cy - radius), (cx + radius, cy + radius)],
               fill=(*color, alpha))
    overlay = overlay.filter(ImageFilter.GaussianBlur(radius=radius / 2.2))
    img.alpha_composite(overlay)


def _draw_window_frame(d: ImageDraw.ImageDraw, x, y, w, h,
                       frame_color, glass_color, mullions=2):
    """Draw a window: outer frame, glass pane, horizontal mullions."""
    d.rectangle([(x, y), (x + w, y + h)], fill=(*frame_color, 255))
    pad = max(4, w // 14)
    d.rectangle([(x + pad, y + pad), (x + w - pad, y + h - pad)],
                fill=(*glass_color, 255))
    if mullions >= 1:
        my = y + h // 2
        d.line([(x + pad, my), (x + w - pad, my)],
               fill=(*frame_color, 255), width=3)
    if mullions >= 2:
        mx = x + w // 2
        d.line([(mx, y + pad), (mx, y + h - pad)],
               fill=(*frame_color, 255), width=3)


# -- 1. first_night -- a small lit lantern flame against a dark window
def render_first_night() -> Image.Image:
    img = _new_canvas()
    d = ImageDraw.Draw(img)
    # dark backdrop (night sky through window)
    _fill_bg(d, C["storm_blue"], alpha=255)
    # subtle stars
    rng = random.Random(11)
    for _ in range(18):
        sx = rng.randint(8, BAKE_SIZE - 8)
        sy = rng.randint(8, BAKE_SIZE // 2 - 6)
        sr = rng.choice([0, 0, 1])
        if sr == 0:
            d.point((sx, sy), fill=(*C["white_warm"], 180))
        else:
            d.ellipse([(sx - 1, sy - 1), (sx + 1, sy + 1)],
                      fill=(*C["white_warm"], 200))
    # window frame
    _draw_window_frame(d, 24, 24, BAKE_SIZE - 48, BAKE_SIZE - 48,
                       C["ash_gray_dark"], C["storm_blue"], mullions=2)
    # darken the glass so the flame is the focal point
    overlay = Image.new("RGBA", img.size, (0, 0, 0, 0))
    od = ImageDraw.Draw(overlay)
    od.rectangle([(28, 28), (BAKE_SIZE - 28, BAKE_SIZE - 28)],
                 fill=(20, 30, 40, 110))
    img.alpha_composite(overlay)
    # halo around the lantern
    _soft_glow(img, (BAKE_SIZE // 2, int(BAKE_SIZE * 0.62)),
               radius=70, color=C["lantern_yellow"], alpha=150)
    # lantern body
    cx = BAKE_SIZE // 2
    base_y = int(BAKE_SIZE * 0.78)
    body_w = 50
    body_h = 40
    d.rectangle([(cx - body_w // 2, base_y - body_h),
                 (cx + body_w // 2, base_y)],
                fill=(*C["ash_gray"], 255))
    # lantern handle
    d.arc([(cx - 18, base_y - body_h - 22), (cx + 18, base_y - body_h + 2)],
          start=180, end=360, fill=(*C["ash_gray_dark"], 255), width=4)
    # lantern glass
    d.rectangle([(cx - 18, base_y - body_h + 6),
                 (cx + 18, base_y - 8)],
                fill=(*C["lantern_yellow"], 230))
    # flame
    flame_cx, flame_cy = cx, base_y - body_h + 4
    d.polygon(
        [(flame_cx, flame_cy - 22),
         (flame_cx - 9, flame_cy - 4),
         (flame_cx - 4, flame_cy + 6),
         (flame_cx + 4, flame_cy + 6),
         (flame_cx + 9, flame_cy - 4)],
        fill=(*C["lantern_glow"], 255))
    d.polygon(
        [(flame_cx, flame_cy - 14),
         (flame_cx - 4, flame_cy - 2),
         (flame_cx, flame_cy + 4),
         (flame_cx + 4, flame_cy - 2)],
        fill=(*C["white_warm"], 230))
    return img


# -- 2. first_contact -- old analog radio dial with one green tick
def render_first_contact() -> Image.Image:
    img = _new_canvas()
    d = ImageDraw.Draw(img)
    # radio body
    body = [36, 60, BAKE_SIZE - 36, BAKE_SIZE - 50]
    d.rounded_rectangle(body, radius=14,
                        fill=(*C["paper"], 255),
                        outline=(*C["ash_gray_dark"], 255), width=4)
    # speaker grille (left half) — vertical slits
    for i in range(7):
        x = body[0] + 16 + i * 9
        d.line([(x, body[1] + 18), (x, body[1] + 70)],
               fill=(*C["ash_gray"], 255), width=2)
    # dial window (right half)
    win = [body[2] - 96, body[1] + 18, body[2] - 18, body[1] + 70]
    d.rectangle(win, fill=(*C["ash_gray_dark"], 255))
    # frequency band — ticks
    band_y = (win[1] + win[3]) // 2
    for i in range(11):
        tx = win[0] + 6 + i * 7
        th = 8 if i % 5 == 0 else 5
        d.line([(tx, band_y - th), (tx, band_y + th)],
               fill=(*C["paper"], 200), width=1)
    # signal tick (green = signal caught) — slightly teal-leaning
    tick_x = win[0] + 6 + 6 * 7  # one position in
    d.rectangle([(tick_x - 3, win[1] + 4), (tick_x + 3, win[3] - 4)],
                fill=(*C["teal_signal"], 255))
    # soft glow behind tick
    _soft_glow(img, (tick_x, (win[1] + win[3]) // 2), radius=20,
               color=C["teal_signal"], alpha=140)
    # needle pointing to it (from below)
    d.line([(tick_x, band_y + 32), (tick_x, band_y + 4)],
           fill=(*C["lantern_yellow"], 255), width=4)
    d.ellipse([(tick_x - 6, band_y + 28), (tick_x + 6, band_y + 40)],
              fill=(*C["lantern_yellow"], 255),
              outline=(*C["rust_dark"], 255), width=2)
    # dial knob
    knob_cx, knob_cy = (body[0] + body[2]) // 2, body[3] - 20
    d.ellipse([(knob_cx - 22, knob_cy - 22), (knob_cx + 22, knob_cy + 22)],
              fill=(*C["paper_dark"], 255),
              outline=(*C["ash_gray_dark"], 255), width=2)
    d.ellipse([(knob_cx - 12, knob_cy - 12), (knob_cx + 12, knob_cy + 12)],
              fill=(*C["ash_gray"], 255))
    # antenna
    d.line([(body[0] + 18, body[1]), (body[0] - 8, body[1] - 36)],
           fill=(*C["ash_gray_dark"], 255), width=3)
    d.ellipse([(body[0] - 12, body[1] - 40), (body[0] - 4, body[1] - 32)],
              fill=(*C["ash_gray_dark"], 255))
    return img


# -- 3. recruit_nora -- wrench crossed with a compass needle
def render_recruit_nora() -> Image.Image:
    img = _new_canvas()
    d = ImageDraw.Draw(img)
    # compass circle (outer)
    cx, cy = BAKE_SIZE // 2, BAKE_SIZE // 2
    r = 100
    d.ellipse([(cx - r, cy - r), (cx + r, cy + r)],
              fill=(*C["paper"], 255),
              outline=(*C["ash_gray_dark"], 255), width=6)
    # inner ring
    d.ellipse([(cx - r + 16, cy - r + 16), (cx + r - 16, cy + r - 16)],
              outline=(*C["ash_gray"], 255), width=2)
    # cardinal tick marks
    for ang in (0, 90, 180, 270):
        rad = math.radians(ang)
        x1 = cx + math.cos(rad) * (r - 12)
        y1 = cy + math.sin(rad) * (r - 12)
        x2 = cx + math.cos(rad) * (r - 26)
        y2 = cy + math.sin(rad) * (r - 26)
        d.line([(x1, y1), (x2, y2)], fill=(*C["ash_gray_dark"], 255), width=4)
    # compass needle (red/teal) — angled N-NE
    angle = math.radians(-25)
    n_len = r - 32
    nx = cx + math.cos(angle) * n_len
    ny = cy + math.sin(angle) * n_len
    sx = cx - math.cos(angle) * (n_len * 0.6)
    sy = cy - math.sin(angle) * (n_len * 0.6)
    d.polygon([(cx, cy), (nx, ny), (cx + 6, cy), (sx, sy)],
              fill=(*C["rust_orange"], 255))
    d.polygon([(cx, cy), (nx, ny), (cx - 6, cy), (sx, sy)],
              fill=(*C["rust_dark"], 255))
    d.ellipse([(cx - 7, cy - 7), (cx + 7, cy + 7)],
              fill=(*C["ash_gray_dark"], 255))
    # wrench — single diagonal across the dial, plus a second crossed one.
    # Wrench: a thick shaft + a circle at the head with an open jaw notch.
    def _wrench(angle_deg, color, dark_color):
        rad = math.radians(angle_deg)
        cos_a, sin_a = math.cos(rad), math.sin(rad)
        shaft_len = 70
        # shaft endpoints
        x1 = cx - cos_a * shaft_len
        y1 = cy - sin_a * shaft_len
        x2 = cx + cos_a * shaft_len
        y2 = cy + sin_a * shaft_len
        d.line([(x1, y1), (x2, y2)], fill=(*color, 255), width=14)
        # head circle at (x2, y2)
        head_r = 18
        d.ellipse([(x2 - head_r, y2 - head_r), (x2 + head_r, y2 + head_r)],
                  fill=(*color, 255), outline=(*dark_color, 255), width=3)
        # notch — a paper-colored rectangle aligned with the wrench axis
        n_h = head_r + 4
        n_w = 8
        # corners of the notch rectangle, rotated by angle
        corners = [(-n_h, -n_w), (n_h, -n_w), (n_h, n_w), (-n_h, n_w)]
        notch = [(x2 + cos_a * dx - sin_a * dy,
                  y2 + sin_a * dx + cos_a * dy) for (dx, dy) in corners]
        d.polygon(notch, fill=(*C["paper"], 255))
    _wrench(45, C["teal_dark"], C["ash_gray_dark"])
    _wrench(45 + 90, C["teal_dark"], C["ash_gray_dark"])
    return img


# -- 4. recruit_elias -- old radio antenna tower with a faint signal arc
def render_recruit_elias() -> Image.Image:
    img = _new_canvas()
    d = ImageDraw.Draw(img)
    # ground
    d.rectangle([(0, BAKE_SIZE - 50), (BAKE_SIZE, BAKE_SIZE)],
                fill=(*C["ash_gray_dark"], 255))
    # ground hatch lines
    for i in range(8):
        y = BAKE_SIZE - 50 + i * 6
        d.line([(0, y), (BAKE_SIZE, y - 4)],
               fill=(*C["ash_gray"], 180), width=1)
    # tower base
    base_x = BAKE_SIZE // 2
    base_y = BAKE_SIZE - 50
    d.polygon(
        [(base_x - 36, base_y), (base_x + 36, base_y),
         (base_x + 6, base_y - 200), (base_x - 6, base_y - 200)],
        fill=(*C["ash_gray"], 255),
        outline=(*C["ash_gray_dark"], 255))
    # cross braces
    for i in range(6):
        y0 = base_y - 30 - i * 28
        y1 = y0 - 22
        w0 = 6 + i * 5
        w1 = 6 + (i + 1) * 5
        d.line([(base_x - w0, y0), (base_x + w0, y0)],
               fill=(*C["ash_gray_dark"], 255), width=2)
        # X-brace
        d.line([(base_x - w0, y0), (base_x + w1, y1)],
               fill=(*C["ash_gray_dark"], 200), width=1)
        d.line([(base_x + w0, y0), (base_x - w1, y1)],
               fill=(*C["ash_gray_dark"], 200), width=1)
    # tower top
    top_y = base_y - 200
    d.line([(base_x, top_y), (base_x, top_y - 24)],
           fill=(*C["ash_gray_dark"], 255), width=4)
    # signal arcs (teal) above the tower — thicker, brighter
    arc_color = C["teal_signal"]
    for r, w, a in [(80, 7, 220), (58, 6, 230), (38, 5, 240)]:
        d.arc([(base_x - r, top_y - r - 40),
               (base_x + r, top_y + r - 40)],
              start=200, end=340, fill=(*arc_color, a), width=w)
    # small red beacon
    _soft_glow(img, (base_x, top_y - 30), radius=24,
               color=C["rust_orange"], alpha=140)
    d.ellipse([(base_x - 4, top_y - 34), (base_x + 4, top_y - 26)],
              fill=(*C["rust_orange"], 255))
    return img


# -- 5. all_three_allies -- three silhouettes (back-view) facing a horizon
def render_all_three_allies() -> Image.Image:
    img = _new_canvas()
    d = ImageDraw.Draw(img)
    # sky gradient via stacked bands (low saturation dusk)
    for i in range(BAKE_SIZE):
        t = i / BAKE_SIZE
        r = int(60 * (1 - t) + 30 * t)
        g = int(78 * (1 - t) + 50 * t)
        b = int(96 * (1 - t) + 70 * t)
        d.line([(0, i), (BAKE_SIZE, i)], fill=(r, g, b, 255))
    # distant horizon glow
    _soft_glow(img, (BAKE_SIZE // 2, int(BAKE_SIZE * 0.55)),
               radius=130, color=C["sky_dawn_pale"], alpha=80)
    # mountains
    d.polygon(
        [(0, int(BAKE_SIZE * 0.62)),
         (40, int(BAKE_SIZE * 0.5)),
         (90, int(BAKE_SIZE * 0.58)),
         (140, int(BAKE_SIZE * 0.45)),
         (200, int(BAKE_SIZE * 0.55)),
         (256, int(BAKE_SIZE * 0.48))],
        fill=(*C["ash_gray_dark"], 255))
    # ground
    d.rectangle([(0, int(BAKE_SIZE * 0.62)),
                 (BAKE_SIZE, BAKE_SIZE)],
                fill=(*C["ash_gray_dark"], 255))
    # three silhouettes (back-view) — different heights, more contrast
    def _silhouette(cx, ground_y, h, hat=True, pack=True, coat=True):
        head_r = 14
        head_y = ground_y - h
        coat_w = 18
        # coat/shoulders
        d.rectangle([(cx - coat_w, head_y + 14),
                     (cx + coat_w, ground_y - 4)],
                    fill=(*C["black"], 255))
        # pack
        if pack:
            d.rectangle([(cx + coat_w - 2, head_y + 22),
                         (cx + coat_w + 14, head_y + 70)],
                        fill=(*C["black"], 255))
        # head
        d.ellipse([(cx - head_r, head_y - head_r),
                   (cx + head_r, head_y + head_r)],
                  fill=(*C["black"], 255))
        if hat:
            d.rectangle([(cx - head_r - 2, head_y - head_r - 2),
                         (cx + head_r + 2, head_y - head_r + 4)],
                        fill=(*C["black"], 255))
            d.rectangle([(cx - head_r - 5, head_y - head_r - 6),
                         (cx + head_r + 5, head_y - head_r - 2)],
                        fill=(*C["black"], 255))
        # legs hint
        d.rectangle([(cx - coat_w + 2, ground_y - 18),
                     (cx - 2, ground_y - 4)],
                    fill=(*C["black"], 255))
        d.rectangle([(cx + 2, ground_y - 18),
                     (cx + coat_w - 2, ground_y - 4)],
                    fill=(*C["black"], 255))
    ground_y = int(BAKE_SIZE * 0.92)
    _silhouette(78,  ground_y, 100, hat=True,  pack=False)
    _silhouette(128, ground_y, 110, hat=True,  pack=True)
    _silhouette(180, ground_y, 100, hat=False, pack=True)
    return img


# -- 6. reach_victor -- headphones with one earcup replaced by an antenna
def render_reach_victor() -> Image.Image:
    img = _new_canvas()
    d = ImageDraw.Draw(img)
    # headband
    d.arc([(40, 60), (BAKE_SIZE - 40, 220)],
          start=180, end=360,
          fill=(*C["ash_gray_dark"], 255), width=10)
    # left earcup (normal)
    lcx, lcy = 70, 170
    d.ellipse([(lcx - 30, lcy - 36), (lcx + 30, lcy + 36)],
              fill=(*C["ash_gray"], 255),
              outline=(*C["ash_gray_dark"], 255), width=4)
    d.ellipse([(lcx - 18, lcy - 22), (lcx + 18, lcy + 22)],
              fill=(*C["ash_gray_dark"], 255))
    # right earcup replaced by antenna base
    rcx, rcy = BAKE_SIZE - 70, 170
    d.ellipse([(rcx - 30, rcy - 36), (rcx + 30, rcy + 36)],
              fill=(*C["teal_dark"], 255),
              outline=(*C["ash_gray_dark"], 255), width=4)
    d.ellipse([(rcx - 18, rcy - 22), (rcx + 18, rcy + 22)],
              fill=(*C["ash_gray_dark"], 255))
    # antenna rod growing up from the right earcup
    d.line([(rcx, rcy - 30), (rcx, 30)],
           fill=(*C["ash_gray_dark"], 255), width=6)
    # crossbars on the antenna
    for i, y in enumerate((50, 80, 110, 140)):
        w = 24 - i * 4
        d.line([(rcx - w, y), (rcx + w, y)],
               fill=(*C["ash_gray_dark"], 255), width=2)
    # antenna tip
    d.ellipse([(rcx - 5, 22), (rcx + 5, 32)],
              fill=(*C["rust_orange"], 255))
    # faint static lines emanating from antenna tip
    for r, a in [(60, 180), (40, 200), (24, 220)]:
        d.arc([(rcx - r, 20 - r // 2),
               (rcx + r, 20 + r // 2)],
              start=200, end=340, fill=(*C["teal_signal"], a), width=3)
    return img


# -- 7. clear_all_nights -- an open palm holding a small sunrise glow
def render_clear_all_nights() -> Image.Image:
    img = _new_canvas()
    d = ImageDraw.Draw(img)
    # sky gradient (sunrise)
    for i in range(BAKE_SIZE):
        t = i / BAKE_SIZE
        r = int(50 * (1 - t) + 220 * t)
        g = int(64 * (1 - t) + 160 * t)
        b = int(80 * (1 - t) + 120 * t)
        d.line([(0, i), (BAKE_SIZE, i)], fill=(r, g, b, 255))
    # horizon line glow
    _soft_glow(img, (BAKE_SIZE // 2, int(BAKE_SIZE * 0.45)),
               radius=140, color=C["sky_dawn"], alpha=110)
    _soft_glow(img, (BAKE_SIZE // 2, int(BAKE_SIZE * 0.48)),
               radius=80, color=C["lantern_glow"], alpha=140)
    # horizon
    d.line([(0, int(BAKE_SIZE * 0.5)),
            (BAKE_SIZE, int(BAKE_SIZE * 0.5))],
           fill=(*C["rust_dark"], 220), width=2)
    # sun arc
    d.arc([(BAKE_SIZE // 2 - 30, int(BAKE_SIZE * 0.42)),
           (BAKE_SIZE // 2 + 30, int(BAKE_SIZE * 0.58))],
          start=180, end=360, fill=(*C["lantern_glow"], 255), width=4)
    # hand (open palm) at bottom
    # forearm
    d.rectangle([(BAKE_SIZE // 2 - 30, int(BAKE_SIZE * 0.78)),
                 (BAKE_SIZE // 2 + 30, BAKE_SIZE)],
                fill=(*C["skin"], 255),
                outline=(*C["skin_dark"], 255), width=3)
    # palm
    pcx, pcy = BAKE_SIZE // 2, int(BAKE_SIZE * 0.74)
    d.ellipse([(pcx - 50, pcy - 28), (pcx + 50, pcy + 28)],
              fill=(*C["skin"], 255),
              outline=(*C["skin_dark"], 255), width=3)
    # four fingers (curled up around the glow)
    for i, dx in enumerate((-32, -12, 8, 28)):
        d.rounded_rectangle(
            [(pcx + dx - 8, pcy - 48), (pcx + dx + 8, pcy - 8)],
            radius=8, fill=(*C["skin"], 255),
            outline=(*C["skin_dark"], 255), width=2)
    # thumb
    d.rounded_rectangle(
        [(pcx - 60, pcy - 18), (pcx - 38, pcy + 4)],
        radius=8, fill=(*C["skin"], 255),
        outline=(*C["skin_dark"], 255), width=2)
    return img


# -- 8. no_breach -- wooden door with all planks intact + a single padlock
def render_no_breach() -> Image.Image:
    img = _new_canvas()
    d = ImageDraw.Draw(img)
    # door frame
    fx, fy = 40, 30
    fw, fh = BAKE_SIZE - 80, BAKE_SIZE - 50
    d.rectangle([(fx, fy), (fx + fw, fy + fh)],
                fill=(*C["ash_gray_dark"], 255))
    # door body
    dx, dy = fx + 8, fy + 8
    dw, dh = fw - 16, fh - 8
    d.rectangle([(dx, dy), (dx + dw, dy + dh)],
                fill=(*C["paper_dark"], 255))
    # planks (3 vertical) with grain
    plank_w = dw // 3
    for i in range(3):
        px = dx + i * plank_w
        d.rectangle([(px + 1, dy + 1), (px + plank_w - 1, dy + dh - 1)],
                    fill=(*C["paper"], 255))
        # grain
        for g in range(8):
            gy = dy + 6 + g * ((dh - 12) // 8)
            d.line([(px + 4, gy), (px + plank_w - 4, gy + 1)],
                   fill=(*C["paper_dark"], 130), width=1)
    # horizontal cross-brace
    by = dy + dh - 36
    d.rectangle([(dx - 2, by), (dx + dw + 2, by + 18)],
                fill=(*C["ash_gray_dark"], 255))
    # nail heads
    for nx in (dx + 10, dx + dw - 10):
        d.ellipse([(nx - 4, by + 5), (nx + 4, by + 13)],
                  fill=(*C["ash_gray_light"], 255))
    # padlock (center, large)
    lcx = dx + dw // 2
    lcy = by - 14
    # shackle
    d.arc([(lcx - 24, lcy - 36), (lcx + 24, lcy + 4)],
          start=180, end=360, fill=(*C["ash_gray_light"], 255), width=8)
    # body
    d.rounded_rectangle([(lcx - 22, lcy - 4), (lcx + 22, lcy + 30)],
                        radius=5, fill=(*C["ash_gray"], 255),
                        outline=(*C["ash_gray_dark"], 255), width=2)
    # keyhole
    d.ellipse([(lcx - 4, lcy + 6), (lcx + 4, lcy + 14)],
              fill=(*C["ash_gray_dark"], 255))
    d.rectangle([(lcx - 2, lcy + 12), (lcx + 2, lcy + 22)],
                fill=(*C["ash_gray_dark"], 255))
    return img


# ---------------------------------------------------------------------------
# Render registry
# ---------------------------------------------------------------------------
RENDERERS = {
    "first_night":       render_first_night,
    "first_contact":     render_first_contact,
    "recruit_nora":      render_recruit_nora,
    "recruit_elias":     render_recruit_elias,
    "all_three_allies":  render_all_three_allies,
    "reach_victor":      render_reach_victor,
    "clear_all_nights":  render_clear_all_nights,
    "no_breach":         render_no_breach,
}

LABELS = {
    "first_night":      "first_night",
    "first_contact":    "first_contact",
    "recruit_nora":     "recruit_nora",
    "recruit_elias":    "recruit_elias",
    "all_three_allies": "all_three_allies",
    "reach_victor":     "reach_victor",
    "clear_all_nights": "clear_all_nights",
    "no_breach":        "no_breach",
}


# ---------------------------------------------------------------------------
# Locked variant: desaturate to luminance + slight darken + alpha *= 0.55
# ---------------------------------------------------------------------------
def to_locked(unlocked_rgba: Image.Image) -> Image.Image:
    """Convert the unlocked RGBA to a locked-state image:
    - convert RGB to luminance grayscale (Rec. 709 weights)
    - multiply alpha by 0.55, slight darken via RGB *= 0.78
    Result: a faint silhouette against transparency; the original shape
    is still readable, but you can't see what's behind the lock.
    """
    src = unlocked_rgba.copy()
    r, g, b, a = src.split()
    # grayscale via Rec. 709
    gray = r.point(lambda v: int(0.2126 * v)) \
        .point(lambda _: 0)  # placeholder, will be replaced below
    # use PIL's L conversion on RGB for proper luminance
    rgb = Image.merge("RGB", (r, g, b))
    lum = rgb.convert("L")
    # slight darken (multiply)
    lum = lum.point(lambda v: max(0, min(255, int(v * 0.78))))
    # build new RGBA: luminance -> RGB, alpha = orig alpha * 0.55
    new_a = a.point(lambda v: int(v * 0.55))
    out = Image.merge("RGBA", (lum, lum, lum, new_a))
    return out


# ---------------------------------------------------------------------------
# Sidecar writer
# ---------------------------------------------------------------------------
def write_import_sidecar(png_path: Path) -> None:
    """Write a .png.import sidecar mirroring assets/final/night_shift/icon_*.png.import.
    The 64x64 Godot-4.3 texture import profile.
    """
    import hashlib
    rel_png = png_path.relative_to(ROOT).as_posix()
    # deterministic-ish uid from filename (Godot accepts any uid:// value;
    # just needs to be unique within the project).
    digest = hashlib.md5(rel_png.encode("utf-8")).hexdigest()[:13]
    uid = f"uid://b8{digest}"
    ctex_name = f"{png_path.stem}-{digest}.ctex"
    ctex_path = f"res://.godot/imported/{ctex_name}"
    body = (
        "[remap]\n"
        "\n"
        f'importer="texture"\n'
        f'type="CompressedTexture2D"\n'
        f'uid="{uid}"\n'
        f'path="{ctex_path}"\n'
        'metadata={\n'
        '"vram_texture": false\n'
        "}\n"
        "\n"
        "[deps]\n"
        "\n"
        f'source_file="res://{rel_png}"\n'
        f'dest_files=["{ctex_path}"]\n'
        "\n"
        "[params]\n"
        "\n"
        "compress/mode=0\n"
        "compress/high_quality=false\n"
        "compress/lossy_quality=0.7\n"
        "compress/hdr_compression=1\n"
        "compress/normal_map=0\n"
        "compress/channel_pack=0\n"
        "mipmaps/generate=false\n"
        "mipmaps/limit=-1\n"
        "roughness/mode=0\n"
        "roughness/src_normal=\"\"\n"
        "process/fix_alpha_border=true\n"
        "process/premult_alpha=false\n"
        "process/normal_map_invert_y=false\n"
        "process/hdr_as_srgb=false\n"
        "process/hdr_clamp_exposure=false\n"
        "process/size_limit=0\n"
        "detect_3d/compress_to=1\n"
    )
    sidecar = png_path.with_suffix(".png.import")
    sidecar.write_text(body, encoding="utf-8")


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
def main() -> int:
    print(f"Output dir: {OUT_DIR}")
    for ach_id, renderer in RENDERERS.items():
        # render at 256
        big = renderer()
        assert big.size == (BAKE_SIZE, BAKE_SIZE)
        # derive locked
        big_locked = to_locked(big)
        # downscale to 64
        unlocked_64 = big.resize((PNG_SIZE, PNG_SIZE), Image.LANCZOS)
        locked_64 = big_locked.resize((PNG_SIZE, PNG_SIZE), Image.LANCZOS)
        upath = OUT_DIR / f"ach_{ach_id}_unlocked.png"
        lpath = OUT_DIR / f"ach_{ach_id}_locked.png"
        unlocked_64.save(upath, "PNG", optimize=True)
        locked_64.save(lpath, "PNG", optimize=True)
        write_import_sidecar(upath)
        write_import_sidecar(lpath)
        print(f"  ach_{ach_id}_unlocked.png + _locked.png  ({PNG_SIZE}x{PNG_SIZE})")
    print(f"Wrote {len(RENDERERS) * 2} PNGs and {len(RENDERERS) * 2} .import sidecars.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
