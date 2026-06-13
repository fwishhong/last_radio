from __future__ import annotations

from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
DOWNLOADS = Path.home() / "Downloads"
OUTPUT_DIR = ROOT / "assets" / "final" / "night_shift"
CANVAS_SIZE = (768, 1024)
WHITE_THRESHOLD = 238


def is_source(path: Path) -> bool:
    return (
        path.suffix.lower() == ".png"
        and "Transparent PNG, full body single" in path.name
        and path.name.startswith("jimeng-2026-06-10-")
    )


def remove_white_and_normalize(src_path: Path, out_path: Path) -> None:
    src = Image.open(src_path).convert("RGBA")
    pixels = src.load()
    width, height = src.size
    min_x, min_y = width, height
    max_x, max_y = -1, -1

    for y in range(height):
        for x in range(width):
            r, g, b, a = pixels[x, y]
            max_c = max(r, g, b)
            min_c = min(r, g, b)
            is_background = (
                r >= WHITE_THRESHOLD
                and g >= WHITE_THRESHOLD
                and b >= WHITE_THRESHOLD
                and max_c - min_c <= 26
            )
            if is_background:
                pixels[x, y] = (r, g, b, 0)
                continue
            pixels[x, y] = (r, g, b, 255)
            min_x = min(min_x, x)
            min_y = min(min_y, y)
            max_x = max(max_x, x)
            max_y = max(max_y, y)

    if max_x <= min_x or max_y <= min_y:
        raise RuntimeError(f"No foreground detected in {src_path}")

    pad = 28
    min_x = max(0, min_x - pad)
    min_y = max(0, min_y - pad)
    max_x = min(width - 1, max_x + pad)
    max_y = min(height - 1, max_y + pad)
    cropped = src.crop((min_x, min_y, max_x + 1, max_y + 1))

    canvas_w, canvas_h = CANVAS_SIZE
    scale = min((canvas_w * 0.84) / cropped.width, (canvas_h * 0.94) / cropped.height)
    draw_w = max(1, round(cropped.width * scale))
    draw_h = max(1, round(cropped.height * scale))
    resized = cropped.resize((draw_w, draw_h), Image.Resampling.LANCZOS)

    canvas = Image.new("RGBA", CANVAS_SIZE, (0, 0, 0, 0))
    draw_x = round((canvas_w - draw_w) / 2)
    draw_y = round(canvas_h - draw_h - 18)
    canvas.alpha_composite(resized, (draw_x, draw_y))
    canvas.save(out_path)
    print(f"Wrote {out_path} from {src_path}")


def main() -> None:
    latest = sorted(
        [path for path in DOWNLOADS.iterdir() if path.is_file() and is_source(path)],
        key=lambda path: path.stat().st_mtime,
        reverse=True,
    )[:3]
    if len(latest) != 3:
        raise RuntimeError(f"Expected three latest player actor source PNG files in {DOWNLOADS}")

    mapping = [
        ("back", latest[0]),
        ("side", latest[1]),
        ("front", latest[2]),
    ]
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    for direction, src_path in mapping:
        remove_white_and_normalize(src_path, OUTPUT_DIR / f"actor_player_{direction}.png")


if __name__ == "__main__":
    main()
