"""
Convert matrix-generated RGB PNG to RGBA PNG with proper transparency.

Strategy v6 (current): auto-detect the matrix checker palette.

  1. Sample 4 small corner regions (50x50 each at TL/TR/BL/BR). These
     are guaranteed background because matrix uses a checker pattern
     that always fills the canvas, including edges.
  2. Compute the mean gray value per corner -> 4 anchors.
  3. Cluster the 4 anchors into 2 typical checker levels (light + dark)
     using the histogram peak within each corner.
  4. A pixel is background if it's near-gray (R==G==B within 8) and its
     value is within 20 of one of the 2 detected checker anchors.

This handles matrix's variable checker palette:
  matrix v1: (185, 125)
  matrix v2: (152, 112)
  matrix v3: (243, 195)
  matrix v4: (124,  80)
  ...future: whatever matrix picks next time.

The 20-unit tolerance around each anchor covers anti-aliased edges.
The 8-unit spread keeps saturated pixels (handle, jacket, jeans) safely
out of background even when their gray channel happens to drift.

Outputs:
  default <src>_rgba.png next to the input PNG

History:
  v3  fixed [100,215] band         -- misses light (255) checker.
  v4  hardcoded {125,185,255}      -- misses v2/v3/v4 palettes.
  v5  fixed [100,165] band         -- misses mid-frame (243,195) palette.
  v6  corner-anchor auto-detect    -- survives any palette matrix picks.
"""

from PIL import Image
import sys

src = sys.argv[1]
dst = sys.argv[2] if len(sys.argv) > 2 else src.replace(".png", "_rgba.png")

img = Image.open(src).convert("RGB")
w, h = img.size
print(f"input: {src}")
print(f"size: {w}x{h}")

# 1+2. Sample 4 corner regions, take the modal gray value per corner.
# Mean is wrong because the 4 corners can each be light or dark checker,
# so the mean lands between the two checker levels. Mode per corner
# gives us the actual checker level present in that corner.
def corner_anchor(side: str) -> int:
	if side == 'tl':
		r0, r1, c0, c1 = 0, 50, 0, 50
	elif side == 'tr':
		r0, r1, c0, c1 = 0, 50, w - 50, w
	elif side == 'bl':
		r0, r1, c0, c1 = h - 50, h, 0, 50
	else:
		r0, r1, c0, c1 = h - 50, h, w - 50, w
	hist = {}
	for y in range(r0, r1):
		for x in range(c0, c1):
			r, g, b = img.getpixel((x, y))
			if r == g == b:
				hist[r] = hist.get(r, 0) + 1
	if not hist:
		return 128
	return max(hist.items(), key=lambda kv: kv[1])[0]

tl = corner_anchor('tl')
tr = corner_anchor('tr')
bl = corner_anchor('bl')
br = corner_anchor('br')

# 3. Use the histogram of all gray pixels to find the 2 checker levels.
# Corner-only sampling fails when 4 corners happen to land on the same
# level (matrix checker is uniform random, can align). Global histogram
# is robust.
gray_hist = {}
sample_step = 4  # sample every 4th pixel for speed
for y in range(0, h, sample_step):
	for x in range(0, w, sample_step):
		r, g, b = img.getpixel((x, y))
		if r == g == b:
			gray_hist[r] = gray_hist.get(r, 0) + 1
if not gray_hist:
	# Fallback to corner anchors if no grays at all.
	gray_hist = {tl: 1, tr: 1, bl: 1, br: 1}
# Pick top 2 peaks (separated by >= 30 to ignore anti-alias bridges).
sorted_grays = sorted(gray_hist.items(), key=lambda kv: -kv[1])
hi_anchor = sorted_grays[0][0]
lo_anchor = sorted_grays[0][0]
for v, _ in sorted_grays[1:]:
	if abs(v - hi_anchor) >= 30:
		lo_anchor = v
		break
ANCHOR_TOL = 20
SPREAD_TOL = 8
print(f"checker anchors: lo={lo_anchor} hi={hi_anchor} (hist peaks: {sorted_grays[:4]})")

out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
out_px = out.load()
in_px = img.load()

bg_count = 0
for y in range(h):
	for x in range(w):
		r, g, b = in_px[x, y]
		mn = min(r, g, b)
		mx = max(r, g, b)
		spread = mx - mn
		if spread < SPREAD_TOL and (abs(mn - lo_anchor) < ANCHOR_TOL or abs(mn - hi_anchor) < ANCHOR_TOL):
			out_px[x, y] = (0, 0, 0, 0)
			bg_count += 1
		else:
			out_px[x, y] = (r, g, b, 255)

out.save(dst)
print(f"output: {dst}")
print(f"bg pixels: {bg_count}/{w*h} ({100*bg_count/(w*h):.1f}%)")
print(f"fg pixels: {w*h - bg_count}/{w*h} ({100*(w*h - bg_count)/(w*h):.1f}%)")