import argparse
import math
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw


ROOT_DIR = Path(__file__).resolve().parents[1]
VENDOR_DIR = ROOT_DIR / ".codex_vendor" / "python"
if VENDOR_DIR.exists():
    sys.path.insert(0, str(VENDOR_DIR))

try:
    import cv2
except ImportError as exc:
    raise SystemExit(
        "Missing cv2. Install opencv-python-headless or run the local setup used by Codex."
    ) from exc


OUTPUT_DIR = ROOT_DIR / "assets" / "final" / "night_shift" / "player_walk"
CANVAS_SIZE = (128, 160)
FOOT_Y = 150
TARGET_BODY_HEIGHT = 126
FRAME_COUNT = 12


def _latest_walk_videos(downloads_dir: Path) -> dict[str, Path]:
    videos = sorted(downloads_dir.glob("*.mp4"), key=lambda path: path.stat().st_mtime, reverse=True)
    selected: dict[str, Path] = {}
    for video in videos[:12]:
        name = video.name
        if "背面" in name and "up" not in selected:
            selected["up"] = video
        elif "正面" in name and "down" not in selected:
            selected["down"] = video
        elif ("侧面" in name or "側面" in name) and "right" not in selected:
            selected["right"] = video
        if len(selected) == 3:
            return selected
    missing = sorted(set(["down", "right", "up"]) - set(selected.keys()))
    raise SystemExit("Could not find latest walk videos for: %s" % ", ".join(missing))


def _read_video_frames(video_path: Path, frame_count: int) -> list[np.ndarray]:
    capture = cv2.VideoCapture(str(video_path))
    if not capture.isOpened():
        raise SystemExit("Could not open video: %s" % video_path)
    total = int(capture.get(cv2.CAP_PROP_FRAME_COUNT))
    if total <= 0:
        raise SystemExit("Video has no readable frames: %s" % video_path)
    indices = np.linspace(0, max(total - 1, 0), frame_count, endpoint=False, dtype=np.int32)
    frames: list[np.ndarray] = []
    for frame_index in indices:
        capture.set(cv2.CAP_PROP_POS_FRAMES, int(frame_index))
        ok, bgr = capture.read()
        if not ok:
            continue
        frames.append(cv2.cvtColor(bgr, cv2.COLOR_BGR2RGB))
    capture.release()
    if not frames:
        raise SystemExit("Could not decode frames from: %s" % video_path)
    return frames


def _background_color(rgb: np.ndarray) -> np.ndarray:
    border = np.concatenate(
        [
            rgb[:14, :, :].reshape(-1, 3),
            rgb[-14:, :, :].reshape(-1, 3),
            rgb[:, :14, :].reshape(-1, 3),
            rgb[:, -14:, :].reshape(-1, 3),
        ],
        axis=0,
    )
    return np.median(border.astype(np.float32), axis=0)


def _largest_foreground_mask(rgb: np.ndarray) -> np.ndarray:
    bg = _background_color(rgb)
    dist = np.linalg.norm(rgb.astype(np.float32) - bg, axis=2)
    mask = (dist > 18).astype(np.uint8) * 255
    kernel = np.ones((5, 5), np.uint8)
    mask = cv2.morphologyEx(mask, cv2.MORPH_OPEN, kernel)
    mask = cv2.morphologyEx(mask, cv2.MORPH_CLOSE, kernel, iterations=2)
    count, labels, stats, _ = cv2.connectedComponentsWithStats(mask, 8)
    if count <= 1:
        return mask

    height, width = mask.shape
    best_label = 0
    best_area = 0
    fallback_label = 0
    fallback_area = 0
    for label in range(1, count):
        x, y, w, h, area = stats[label]
        touches_edge = x <= 2 or y <= 2 or x + w >= width - 2
        if area > fallback_area:
            fallback_area = area
            fallback_label = label
        if not touches_edge and area > best_area:
            best_area = area
            best_label = label
    if best_label == 0:
        best_label = fallback_label

    component = (labels == best_label).astype(np.uint8) * 255
    component = cv2.dilate(component, np.ones((3, 3), np.uint8), iterations=1)
    return component


def _rgba_cutout(rgb: np.ndarray) -> Image.Image:
	mask = _largest_foreground_mask(rgb)
	channel_max = rgb.max(axis=2)
	channel_min = rgb.min(axis=2)
	brightness = rgb.mean(axis=2)
	y_positions = np.arange(rgb.shape[0])[:, None]
	bright_neutral = (brightness > 174) & ((channel_max - channel_min) < 42)
	floor_neutral = (y_positions > rgb.shape[0] * 0.58) & (brightness > 126) & ((channel_max - channel_min) < 54)
	mask[bright_neutral] = 0
	mask[floor_neutral] = 0
	mask = cv2.morphologyEx(mask, cv2.MORPH_CLOSE, np.ones((3, 3), np.uint8), iterations=1)
	alpha = cv2.GaussianBlur(mask, (5, 5), 0)
	rgba = np.dstack([rgb, alpha])
	return Image.fromarray(rgba.astype(np.uint8), "RGBA")


def _content_bbox(image: Image.Image) -> tuple[int, int, int, int]:
    alpha = np.array(image.getchannel("A"))
    ys, xs = np.where(alpha > 12)
    if not len(xs):
        return (0, 0, image.width, image.height)
    return (int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1)


def _normalize_direction(frames: list[Image.Image]) -> list[Image.Image]:
    boxes = [_content_bbox(frame) for frame in frames]
    max_w = max(box[2] - box[0] for box in boxes)
    max_h = max(box[3] - box[1] for box in boxes)
    scale = min((CANVAS_SIZE[0] - 12) / max_w, TARGET_BODY_HEIGHT / max_h)
    normalized: list[Image.Image] = []
    for frame, box in zip(frames, boxes):
        cropped = frame.crop(box)
        size = (
            max(1, int(round(cropped.width * scale))),
            max(1, int(round(cropped.height * scale))),
        )
        resized = cropped.resize(size, Image.Resampling.LANCZOS)
        canvas = Image.new("RGBA", CANVAS_SIZE, (0, 0, 0, 0))
        x = (CANVAS_SIZE[0] - size[0]) // 2
        y = FOOT_Y - size[1]
        canvas.alpha_composite(resized, (x, y))
        normalized.append(canvas)
    return normalized


def _save_direction(name: str, frames: list[Image.Image]) -> None:
    for index, frame in enumerate(frames):
        frame.save(OUTPUT_DIR / f"{name}_{index:02d}.png")


def _save_contact_sheet(directions: dict[str, list[Image.Image]]) -> None:
    labels = ["down", "right", "left", "up"]
    tile_w, tile_h = CANVAS_SIZE
    sheet = Image.new("RGBA", (tile_w * FRAME_COUNT, (tile_h + 18) * len(labels)), (22, 24, 27, 255))
    draw = ImageDraw.Draw(sheet)
    for row, label in enumerate(labels):
        draw.text((4, row * (tile_h + 18) + 2), label, fill=(235, 235, 225, 255))
        for col, frame in enumerate(directions[label]):
            sheet.alpha_composite(frame, (col * tile_w, row * (tile_h + 18) + 18))
    sheet.save(OUTPUT_DIR / "_player_walk_contact_sheet.png")


def extract(downloads_dir: Path) -> None:
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    for existing in OUTPUT_DIR.glob("*.png"):
        existing.unlink()

    videos = _latest_walk_videos(downloads_dir)
    directions: dict[str, list[Image.Image]] = {}
    for direction, path in videos.items():
        cutouts = [_rgba_cutout(frame) for frame in _read_video_frames(path, FRAME_COUNT)]
        directions[direction] = _normalize_direction(cutouts)

    directions["left"] = [frame.transpose(Image.Transpose.FLIP_LEFT_RIGHT) for frame in directions["right"]]
    for direction in ["down", "right", "left", "up"]:
        _save_direction(direction, directions[direction])
    _save_contact_sheet(directions)

    print("Extracted player walk frames:")
    for direction in ["down", "right", "left", "up"]:
        print("  %s: %d frames" % (direction, len(directions[direction])))
    for direction, path in videos.items():
        print("  source %s: %s" % (direction, path))


def main() -> None:
    parser = argparse.ArgumentParser(description="Extract transparent player walk frames from the latest walk videos.")
    parser.add_argument(
        "--downloads",
        type=Path,
        default=Path.home() / "Downloads",
        help="Directory containing the latest front/back/side walk mp4 files.",
    )
    args = parser.parse_args()
    extract(args.downloads)


if __name__ == "__main__":
    main()
