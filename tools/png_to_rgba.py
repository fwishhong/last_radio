"""
Convert matrix-generated RGB PNG to RGBA PNG with proper transparency.
Strategy v3: a pixel is background if it's near-gray and mid-bright.
  - max(R,G,B) - min(R,G,B) < 25   (near-gray)
  - 100 <= min(R,G,B) and max(R,G,B) <= 210
Hammer head steel is around 200-225 (avg ~210) and is a single uniform
gray, but the matrix checker sits at 125/185 which falls inside the
range. We pick the larger band: keep pixels that are clearly
*non-gray* (high color saturation) or clearly *dark* (the black outline)
or clearly *bright* (highlights) as foreground.

Outputs:
  default <src>_rgba.png next to the input PNG
"""

from PIL import Image
import sys

src = sys.argv[1]
dst = sys.argv[2] if len(sys.argv) > 2 else src.replace(".png", "_rgba.png")

img = Image.open(src).convert("RGB")
w, h = img.size
print(f"input: {src}")
print(f"size: {w}x{h}")

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
        # Background criteria: near-gray AND mid-bright (the checker
        # pattern at 125 and 185). Anything with significant color
        # saturation (the orange handle, the warm-cedar wood grain,
        # the steel highlights) stays foreground. Pure black outline
        # also stays foreground.
        if spread < 25 and 100 <= mn and mx <= 215:
            out_px[x, y] = (0, 0, 0, 0)
            bg_count += 1
        else:
            out_px[x, y] = (r, g, b, 255)

out.save(dst)
print(f"output: {dst}")
print(f"bg pixels: {bg_count}/{w*h} ({100*bg_count/(w*h):.1f}%)")
print(f"fg pixels: {w*h - bg_count}/{w*h} ({100*(w*h - bg_count)/(w*h):.1f}%)")