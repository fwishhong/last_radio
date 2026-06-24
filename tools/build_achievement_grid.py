"""
build_achievement_grid.py
Composes a labeled 8x2 grid PNG (unlocked + locked) of the 16 achievement
icons for visual review. Output:
  screenshots/art_audit/achievements_grid_pillow.png
"""
from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(r"C:\Users\Administrator\Desktop\codex\last_radio v2")
ACH_DIR = ROOT / "assets" / "final" / "achievements"
OUT = ROOT / "screenshots" / "art_audit" / "achievements_grid_pillow.png"
OUT.parent.mkdir(parents=True, exist_ok=True)

ACHIEVEMENTS = [
	("first_night",       "活过第一夜"),
	("first_contact",     "首次联络"),
	("recruit_nora",      "Nora 加入"),
	("recruit_elias",     "Elias 加入"),
	("all_three_allies",  "三人齐聚"),
	("reach_victor",      "接通 Victor"),
	("clear_all_nights",  "十夜生存"),
	("no_breach",         "零失守"),
]

# Layout — keep the grid compact but readable
CELL_W, CELL_H = 156, 140        # per row; 156x140 to fit 128px icons
ICON_ZOOM = 2                    # 64*2 = 128px display
ICON_PX = 64 * ICON_ZOOM
LABEL_W = 240
HEADER_H = 64
PAD = 18
ROW_GAP = 4

W = LABEL_W + PAD + CELL_W + PAD + CELL_W + PAD
H = HEADER_H + len(ACHIEVEMENTS) * (CELL_H + ROW_GAP) + 38

# Palette (sober)
BG = (45, 42, 40, 255)
PANEL = (62, 56, 50, 255)
FG = (235, 220, 190, 255)
FG_DIM = (170, 155, 130, 255)
DIV = (90, 82, 72, 255)


def _try_font(size: int, cjk: bool = False):
	# Always try a CJK-capable font first if cjk=True, then fall back.
	candidates = []
	if cjk:
		candidates += [
			r"C:\Windows\Fonts\msyh.ttc",
			r"C:\Windows\Fonts\msyh.ttf",
			r"C:\Windows\Fonts\simhei.ttf",
			r"C:\Windows\Fonts\simsun.ttc",
		]
	candidates += [
		r"C:\Windows\Fonts\segoeui.ttf",
		r"C:\Windows\Fonts\arial.ttf",
	]
	for p in candidates:
		if Path(p).exists():
			try:
				return ImageFont.truetype(p, size)
			except Exception:
				continue
	return ImageFont.load_default()


img = Image.new("RGBA", (W, H), BG)
d = ImageDraw.Draw(img)

font_title = _try_font(24)
font_h = _try_font(15)
font_id = _try_font(15)
font_cn = _try_font(15, cjk=True)
font_foot = _try_font(11)

# title
d.text((PAD, 16), "Last Radio — Achievement Icons", fill=FG, font=font_title)
d.text((PAD, 44), "unlocked (left)  ·  locked (right)  ·  64x64 native",
       fill=FG_DIM, font=font_foot)

# column headers
hx1 = LABEL_W + PAD + CELL_W // 2
hx2 = LABEL_W + PAD + CELL_W + PAD + CELL_W // 2
d.text((hx1 - 40, HEADER_H - 22), "UNLOCKED", fill=FG, font=font_h)
d.text((hx2 - 28, HEADER_H - 22), "LOCKED", fill=FG_DIM, font=font_h)

# rows
for i, (ach_id, cn) in enumerate(ACHIEVEMENTS):
	row_y = HEADER_H + i * (CELL_H + ROW_GAP)
	# row panel
	d.rectangle([(0, row_y), (W, row_y + CELL_H)],
				fill=PANEL if i % 2 == 0 else (54, 49, 44, 255))
	# label column
	d.text((PAD, row_y + 10), ach_id, fill=FG, font=font_id)
	d.text((PAD, row_y + 30), cn, fill=FG_DIM, font=font_cn)
	d.text((PAD, row_y + 54), f"ach_{ach_id}_*.png", fill=(120, 110, 95, 255),
		   font=font_foot)
	# divider
	d.line([(LABEL_W + PAD, row_y + 6),
			(LABEL_W + PAD, row_y + CELL_H - 6)],
		   fill=DIV, width=1)
	# unlocked cell
	cx1 = LABEL_W + PAD + (CELL_W - ICON_PX) // 2
	cy1 = row_y + (CELL_H - ICON_PX) // 2
	try:
		u = Image.open(ACH_DIR / f"ach_{ach_id}_unlocked.png").convert("RGBA")
		u = u.resize((ICON_PX, ICON_PX), Image.LANCZOS)
		img.paste(u, (cx1, cy1), u)
	except FileNotFoundError:
		d.text((cx1 + 8, cy1 + 24), "missing", fill=(220, 80, 80, 255),
			   font=font_foot)
	# locked cell
	cx2 = LABEL_W + PAD + CELL_W + PAD + (CELL_W - ICON_PX) // 2
	cy2 = row_y + (CELL_H - ICON_PX) // 2
	try:
		l = Image.open(ACH_DIR / f"ach_{ach_id}_locked.png").convert("RGBA")
		l = l.resize((ICON_PX, ICON_PX), Image.LANCZOS)
		img.paste(l, (cx2, cy2), l)
	except FileNotFoundError:
		d.text((cx2 + 8, cy2 + 24), "missing", fill=(220, 80, 80, 255),
			   font=font_foot)

img.save(OUT, "PNG", optimize=True)
print(f"saved {OUT}  ({W}x{H})")
