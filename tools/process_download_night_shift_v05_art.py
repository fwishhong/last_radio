from pathlib import Path
from PIL import Image, ImageOps
import datetime


ROOT = Path(r"C:/Users/Administrator/Desktop/codex/last_radio")
DOWNLOADS = Path(r"C:/Users/Administrator/Downloads")
OUT = ROOT / "assets/final/night_shift"
START = datetime.datetime(2026, 6, 5, 0, 0, 0).timestamp()


EVENT_MAP = {
    1: "event_door_reinforce",
    2: "event_window_brace",
    3: "event_generator_tune",
    4: "event_antenna_anchor",
    5: "event_storage",
    6: "event_medbay",
    7: "event_floodlights",
    8: "event_second_plank",
    9: "event_command_routine",
    10: "event_runner_path",
    11: "event_elias_tools",
    12: "event_all_hands",
    13: "event_radio_beacon",
}

def sorted_sources() -> list[Path]:
    return sorted(
        [
            path
            for path in DOWNLOADS.iterdir()
            if path.is_file()
            and path.suffix.lower() == ".png"
            and path.stat().st_mtime >= START
        ],
        key=lambda path: path.stat().st_mtime,
    )


def event_panel(image: Image.Image) -> Image.Image:
    return ImageOps.fit(image.convert("RGB"), (768, 432), Image.Resampling.LANCZOS, centering=(0.5, 0.5))


def main() -> None:
    files = sorted_sources()
    if len(files) < 17:
        raise RuntimeError(f"Expected at least 17 images from 2026-06-05, found {len(files)}.")

    for index, name in EVENT_MAP.items():
        source = files[index]
        target = OUT / f"{name}.png"
        event_panel(Image.open(source)).save(target)
        print(f"wrote {target.name} from {source.name}")

    skipped = [files[0].name] + [files[index].name for index in [14, 15, 16]]
    print("skipped reference images:")
    for name in skipped:
        print(f"  {name}")


if __name__ == "__main__":
    main()
