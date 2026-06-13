from pathlib import Path
from PIL import Image, ImageEnhance, ImageFilter, ImageOps
import datetime
import math
import statistics


ROOT = Path(r"C:/Users/Administrator/Desktop/codex/last_radio")
DOWNLOADS = Path(r"C:/Users/Administrator/Downloads")
OUT = ROOT / "assets/final/night_shift"


def sorted_sources() -> list[Path]:
    start = datetime.datetime(2026, 6, 4, 0, 0, 0).timestamp()
    end = datetime.datetime(2026, 6, 5, 0, 0, 0).timestamp()
    files = sorted(
        [
            path
            for path in DOWNLOADS.iterdir()
            if path.is_file()
            and path.suffix.lower() == ".png"
            and start <= path.stat().st_mtime < end
        ],
        key=lambda p: p.stat().st_mtime,
    )
    if len(files) < 7:
        raise RuntimeError("Expected seven generated night-shift sheets from 2026-06-04 in Downloads.")
    return files


def bg_color(image: Image.Image) -> tuple[int, int, int]:
    rgb = image.convert("RGB")
    width, height = rgb.size
    points: list[tuple[int, int, int]] = []
    for x in list(range(0, width, max(1, width // 50))) + [width - 1]:
        for y in [0, 1, 2, height - 3, height - 2, height - 1]:
            points.append(rgb.getpixel((x, y)))
    for y in list(range(0, height, max(1, height // 50))) + [height - 1]:
        for x in [0, 1, 2, width - 3, width - 2, width - 1]:
            points.append(rgb.getpixel((x, y)))
    return tuple(int(statistics.median([p[i] for p in points])) for i in range(3))


def crop_equal(image: Image.Image, count: int, index: int, margin: int = 0) -> Image.Image:
    width, height = image.size
    slot_width = width / count
    left = int(index * slot_width) + margin
    right = int((index + 1) * slot_width) - margin
    return image.crop((left, 0, right, height))


def transparent_asset(slot: Image.Image, size: int = 256) -> Image.Image:
    rgba = slot.convert("RGBA")
    bg = bg_color(rgba)
    width, height = rgba.size
    pixels = rgba.load()
    alpha = Image.new("L", (width, height), 0)
    alpha_pixels = alpha.load()

    for y in range(height):
        for x in range(width):
            r, g, b, a = pixels[x, y]
            distance = math.sqrt((r - bg[0]) ** 2 + (g - bg[1]) ** 2 + (b - bg[2]) ** 2)
            value = 0
            if distance > 14:
                value = int(max(0, min(255, (distance - 14) * 8)))
            if a < 255:
                value = min(value, a)
            alpha_pixels[x, y] = value

    alpha = alpha.filter(ImageFilter.GaussianBlur(0.7))
    bbox = alpha.getbbox() or (0, 0, width, height)
    pad = 18
    left, top, right, bottom = bbox
    left = max(0, left - pad)
    top = max(0, top - pad)
    right = min(width, right + pad)
    bottom = min(height, bottom + pad)

    cropped = rgba.crop((left, top, right, bottom))
    cropped_alpha = alpha.crop((left, top, right, bottom))
    cropped.putalpha(cropped_alpha)
    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    cropped.thumbnail((size - 16, size - 16), Image.Resampling.LANCZOS)
    canvas.paste(cropped, ((size - cropped.width) // 2, (size - cropped.height) // 2), cropped)
    return canvas


def process_hotspot_sheet(path: Path, names: list[str]) -> None:
    image = Image.open(path).convert("RGB")
    for index, name in enumerate(names):
        slot = crop_equal(image, len(names), index, 8)
        asset = transparent_asset(slot, 256)
        target = OUT / f"{name}.png"
        asset.save(target)
        print(f"wrote {target}")


def process_character_sheet(path: Path) -> None:
    image = Image.open(path).convert("RGB")
    for index, name in enumerate(["character_player", "character_nora", "character_elias"]):
        slot = crop_equal(image, 6, index, 8)
        asset = transparent_asset(slot, 512)
        alpha = asset.getchannel("A")
        rgb = asset.convert("RGB")
        rgb = ImageEnhance.Brightness(rgb).enhance(1.45)
        rgb = ImageEnhance.Contrast(rgb).enhance(1.18)
        asset = rgb.convert("RGBA")
        asset.putalpha(alpha)
        target = OUT / f"{name}.png"
        asset.save(target)
        print(f"wrote {target}")
    for index, name in enumerate(["portrait_player", "portrait_nora", "portrait_elias"], start=3):
        slot = crop_equal(image, 6, index, 8)
        asset = transparent_asset(slot, 384)
        target = OUT / f"{name}.png"
        asset.save(target)
        print(f"wrote {target}")


def process_panel_sheet(path: Path, names: list[str], target_size: tuple[int, int]) -> None:
    image = Image.open(path).convert("RGB")
    for index, name in enumerate(names):
        slot = crop_equal(image, len(names), index, 4)
        width, height = slot.size
        slot = slot.crop((8, 8, width - 8, height - 8))
        slot = ImageOps.fit(slot, target_size, Image.Resampling.LANCZOS, centering=(0.5, 0.5))
        target = OUT / f"{name}.png"
        slot.save(target)
        print(f"wrote {target}")


def main() -> None:
    files = sorted_sources()
    process_hotspot_sheet(
        files[0],
        [
            "back_door_intact",
            "back_door_warning",
            "back_door_assault",
            "back_door_braced",
            "back_door_broken",
        ],
    )
    process_hotspot_sheet(
        files[1],
        ["medbay_idle", "medbay_warning", "medbay_treating", "medbay_critical"],
    )
    process_hotspot_sheet(
        files[2],
        ["storage_idle", "storage_shortage", "storage_repairing", "storage_empty"],
    )
    process_panel_sheet(
        files[3],
        [
            "event_back_door_bar",
            "event_generator_cage",
            "event_medbay_lamp",
            "event_salvage_planks",
            "event_signal_battery",
            "event_final_barricade",
        ],
        (768, 432),
    )
    process_panel_sheet(files[4], ["ending_stadium_dawn", "ending_breach_night"], (960, 540))
    process_character_sheet(files[5])
    process_hotspot_sheet(
        files[6],
        ["threat_front_door", "threat_left_window", "threat_right_window", "threat_back_door"],
    )


if __name__ == "__main__":
    main()
