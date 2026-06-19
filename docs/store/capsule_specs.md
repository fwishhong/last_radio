# Steam Capsule Image Specs

> Source-of-truth for the image files Steam needs. The script
> `tools/build_capsules.ps1` reads this table and produces the files.
>
> Update sizes here when Steam changes its requirements.

## Required files (placed in `build/store_capsules/`)

| File                | Size          | Use                                |
|---------------------|---------------|------------------------------------|
| `header_capsule.png`| 460 × 215     | Library header (small library view)|
| `main_capsule.png`  | 616 × 353     | Store main capsule                 |
| `small_capsule.png` | 230 × 307     | Store small capsule                |
| `library_hero.png`  | 3840 × 1240   | Library hero (Featured & Recommended) |
| `library_logo.png`  | 1280 × 720    | Library logo overlay (transparent PNG) |

## Source artwork

| Source                       | Notes                                  |
|------------------------------|----------------------------------------|
| `icon.png` (512 × 512)       | Master app icon. All capsules build from this. |
| `default_splash.png` (1280×720) | Title-screen background; reused for trailer frame 0. |
| `art_download_preview_grid.png` | Art overview contact sheet; good for "more screenshots" panel. |

## Build approach (build_capsules.ps1)

1. Read `icon.png` (or fallback to a generated key art from
   `assets/lighthouse_keyart.png` if present).
2. Letterbox + center-scale each source to the target size.
3. Output as PNG with no alpha (header / main / small / hero) or alpha
   preserved (logo).

The script uses PowerShell + System.Drawing (GDI+). No ImageMagick required.

## Trailer cover / outro

| File                    | Size          |
|-------------------------|---------------|
| `trailer_cover.png`     | 1280 × 720    |
| `trailer_thumbnail.png` | 1280 × 720    |

Generated from `screenshots/store/night_shift_17_final.png` with the title
overlay added.

## Color palette (for caption / overlay work)

| Token    | Hex       | Use                              |
|----------|-----------|----------------------------------|
| bg-deep  | `#101418` | Title screen / cover dark base   |
| ink      | `#F6F1E0` | Caption text                     |
| amber    | `#F5C76A` | Accent / key art highlights      |
| rust     | `#C97C5F` | Warning / nightfall              |
| cool     | `#9CD9FF` | Elias / radio dial               |
