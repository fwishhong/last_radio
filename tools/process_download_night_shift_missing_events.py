from pathlib import Path
import argparse
import re

from PIL import Image, ImageOps


ROOT = Path(r"C:/Users/Administrator/Desktop/codex/last_radio")
DOWNLOADS = Path(r"C:/Users/Administrator/Downloads")
OUT = ROOT / "assets/final/night_shift"

EVENT_NAMES = [
    "event_nora_kit",
    "event_quiet_hours",
    "event_double_brace",
    "event_victor_cache",
    "event_cable_route",
]


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Process the five missing NightShift event images into formal 768x432 assets."
    )
    parser.add_argument(
        "--latest-five",
        action="store_true",
        help="Use the five newest image files in Downloads. Intended only right after generating the batch.",
    )
    parser.add_argument(
        "--source",
        action="append",
        default=[],
        help="Explicit source image path. Provide exactly five, in event_nora_kit through event_cable_route order.",
    )
    parser.add_argument(
        "--apply",
        action="store_true",
        help="Write assets. Without this flag the script only prints the planned mapping.",
    )
    return parser.parse_args()


def latest_sources() -> list[Path]:
    files = sorted(
        [
            path
            for path in DOWNLOADS.iterdir()
            if path.is_file() and path.suffix.lower() in [".png", ".jpg", ".jpeg", ".webp"]
        ],
        key=lambda path: (path.stat().st_mtime, path.name),
    )[-5:]

    def natural_key(path: Path) -> tuple[int, float, str]:
        match = re.search(r"\((\d+)\)", path.stem)
        suffix_index = int(match.group(1)) if match else 999
        return (suffix_index, path.stat().st_mtime, path.name)

    return sorted(files, key=natural_key)


def explicit_sources(values: list[str]) -> list[Path]:
    sources = []
    for value in values:
        source = Path(value)
        if not source.is_absolute():
            source = ROOT / source
        if not source.exists():
            raise FileNotFoundError(source)
        sources.append(source)
    return sources


def event_panel(image: Image.Image) -> Image.Image:
    return ImageOps.fit(image.convert("RGB"), (768, 432), Image.Resampling.LANCZOS, centering=(0.5, 0.5))


def main() -> None:
    args = parse_args()
    if args.latest_five == (len(args.source) > 0):
        raise RuntimeError("Choose either --latest-five or five --source paths.")
    sources = latest_sources() if args.latest_five else explicit_sources(args.source)
    if len(sources) != len(EVENT_NAMES):
        raise RuntimeError(f"Expected {len(EVENT_NAMES)} source images, found {len(sources)}.")

    OUT.mkdir(parents=True, exist_ok=True)
    for source, name in zip(sources, EVENT_NAMES):
        target = OUT / f"{name}.png"
        print(f"{target.name} <- {source.name}")
        if not args.apply:
            continue
        with Image.open(source) as image:
            event_panel(image).save(target)
        print(f"wrote {target}")
    if not args.apply:
        print("dry run only; add --apply to write files")


if __name__ == "__main__":
    main()
