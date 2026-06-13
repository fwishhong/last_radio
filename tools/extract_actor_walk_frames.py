import argparse
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
    raise SystemExit("Missing cv2. Install opencv-python-headless first.") from exc


FINAL_DIR = ROOT_DIR / "assets" / "final" / "night_shift"
CANVAS_SIZE = (128, 160)
FOOT_Y = 150
TARGET_BODY_HEIGHT = 126
FRAME_COUNT = 12
DIRECTIONS = ["down", "right", "left", "up"]


def _direction_from_name(path: Path) -> str:
    name = path.name
    if "背面" in name:
        return "up"
    if "正面" in name:
        return "down"
    if "侧面" in name or "側面" in name:
        return "right"
    raise ValueError("Cannot infer direction from filename: %s" % path)


def _latest_actor_groups(downloads_dir: Path) -> dict[str, dict[str, Path]]:
    videos = sorted(downloads_dir.glob("*.mp4"), key=lambda path: path.stat().st_mtime, reverse=True)[:6]
    if len(videos) < 6:
        raise SystemExit("Need six latest actor walk videos; found %d." % len(videos))
    groups = {
        "elias": videos[:3],
        "nora": videos[3:6],
    }
    selected: dict[str, dict[str, Path]] = {}
    for actor, actor_videos in groups.items():
        selected[actor] = {}
        for video in actor_videos:
            direction = _direction_from_name(video)
            selected[actor][direction] = video
        missing = sorted(set(["down", "right", "up"]) - set(selected[actor].keys()))
        if missing:
            raise SystemExit("%s is missing walk directions: %s" % (actor, ", ".join(missing)))
    return selected


def _read_video_frames(video_path: Path) -> list[np.ndarray]:
    capture = cv2.VideoCapture(str(video_path))
    if not capture.isOpened():
        raise SystemExit("Could not open video: %s" % video_path)
    total = int(capture.get(cv2.CAP_PROP_FRAME_COUNT))
    if total <= 0:
        raise SystemExit("Video has no readable frames: %s" % video_path)
    indices = np.linspace(0, max(total - 1, 0), FRAME_COUNT, endpoint=False, dtype=np.int32)
    frames: list[np.ndarray] = []
    for frame_index in indices:
        capture.set(cv2.CAP_PROP_POS_FRAMES, int(frame_index))
        ok, bgr = capture.read()
        if ok:
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


def _foreground_mask(rgb: np.ndarray) -> np.ndarray:
    bg = _background_color(rgb)
    dist = np.linalg.norm(rgb.astype(np.float32) - bg, axis=2)
    hsv = cv2.cvtColor(rgb, cv2.COLOR_RGB2HSV)
    green_bg = (hsv[:, :, 0] > 35) & (hsv[:, :, 0] < 95) & (hsv[:, :, 1] > 42) & (hsv[:, :, 2] > 38)
    mask = ((dist > 20) & (~green_bg)).astype(np.uint8) * 255
    mask = cv2.morphologyEx(mask, cv2.MORPH_OPEN, np.ones((3, 3), np.uint8))
    mask = cv2.morphologyEx(mask, cv2.MORPH_CLOSE, np.ones((5, 5), np.uint8), iterations=2)

    count, labels, stats, _ = cv2.connectedComponentsWithStats(mask, 8)
    if count <= 1:
        return mask
    best_label = 0
    best_area = 0
    for label in range(1, count):
        x, y, w, _h, area = stats[label]
        touches_side_or_top = x <= 2 or y <= 2 or x + w >= mask.shape[1] - 2
        if not touches_side_or_top and area > best_area:
            best_area = area
            best_label = label
    if best_label == 0:
        best_label = int(np.argmax(stats[1:, cv2.CC_STAT_AREA])) + 1
    component = (labels == best_label).astype(np.uint8) * 255
    return cv2.dilate(component, np.ones((3, 3), np.uint8), iterations=1)


def _rgba_cutout(rgb: np.ndarray) -> Image.Image:
    mask = _foreground_mask(rgb)
    alpha = cv2.GaussianBlur(mask, (5, 5), 0)
    return Image.fromarray(np.dstack([rgb, alpha]).astype(np.uint8), "RGBA")


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
        canvas.alpha_composite(resized, ((CANVAS_SIZE[0] - size[0]) // 2, FOOT_Y - size[1]))
        normalized.append(canvas)
    return normalized


def _save_actor(actor: str, videos: dict[str, Path]) -> None:
    output_dir = FINAL_DIR / ("%s_walk" % actor)
    output_dir.mkdir(parents=True, exist_ok=True)
    for existing in output_dir.glob("*.png"):
        existing.unlink()

    directions: dict[str, list[Image.Image]] = {}
    for direction in ["down", "right", "up"]:
        cutouts = [_rgba_cutout(frame) for frame in _read_video_frames(videos[direction])]
        directions[direction] = _normalize_direction(cutouts)
    directions["left"] = [frame.transpose(Image.Transpose.FLIP_LEFT_RIGHT) for frame in directions["right"]]

    for direction in DIRECTIONS:
        for index, frame in enumerate(directions[direction]):
            frame.save(output_dir / f"{direction}_{index:02d}.png")
    _save_contact_sheet(output_dir / ("_%s_walk_contact_sheet.png" % actor), directions)


def _save_contact_sheet(path: Path, directions: dict[str, list[Image.Image]]) -> None:
    tile_w, tile_h = CANVAS_SIZE
    sheet = Image.new("RGBA", (tile_w * FRAME_COUNT, (tile_h + 18) * len(DIRECTIONS)), (22, 24, 27, 255))
    draw = ImageDraw.Draw(sheet)
    for row, direction in enumerate(DIRECTIONS):
        draw.text((4, row * (tile_h + 18) + 2), direction, fill=(235, 235, 225, 255))
        for col, frame in enumerate(directions[direction]):
            sheet.alpha_composite(frame, (col * tile_w, row * (tile_h + 18) + 18))
    sheet.save(path)


def main() -> None:
    parser = argparse.ArgumentParser(description="Extract Nora/Elias walk frames from the latest six green-screen videos.")
    parser.add_argument("--downloads", type=Path, default=Path.home() / "Downloads")
    args = parser.parse_args()

    groups = _latest_actor_groups(args.downloads)
    for actor, videos in groups.items():
        _save_actor(actor, videos)
        print("Extracted %s walk frames:" % actor)
        for direction, path in sorted(videos.items()):
            print("  %s: %s" % (direction, path))


if __name__ == "__main__":
    main()
