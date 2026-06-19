# 60-Second Steam Trailer — Shot List & Script

> Total runtime: **59.5 seconds** (Steam allows up to 60).
> Output: `build/trailer/trailer_60s.mp4` (H.264, 1280×720, 30 fps).
> Audio: BGM fade-in / fade-out around `assets/audio/music_night_early.mp3`.
> Captions burned into frames via ffmpeg `drawtext` — see
> `tools/build_trailer.ps1`.

---

## Storyboard

| #  | Time (s) | Visual                                       | Caption (zh)                  | Caption (en)                  | Audio           |
|----|----------|----------------------------------------------|-------------------------------|-------------------------------|-----------------|
| 1  | 0.0–4.5  | night_shift_00_cover.png (zoom-in slow)      | 旧体育馆,十个夜晚             | The old stadium. Ten nights.  | BGM fade-in     |
| 2  | 4.5–9.0  | night_shift_01_start.png (slide-in from right) | 白天做选择                    | Spend the day choosing.       | BGM             |
| 3  | 9.0–13.5 | night_shift_13_day_upgrade_choices.png       | 木板、零件、电池、药品        | Planks. Parts. Batteries. Medicine. | BGM             |
| 4  | 13.5–18.0| night_shift_03_double_window.png             | 夜晚,你亲自上场              | At night, you hold the line.  | BGM swell       |
| 5  | 18.0–22.5| night_shift_07_back_door.png                 | 门窗、电力、避难者            | Doors. Power. Survivors.      | BGM             |
| 6  | 22.5–27.0| night_shift_06_antenna.png                   | 天线架起来,Elias 才清晰      | Raise the antenna. Elias comes in clear. | BGM             |
| 7  | 27.0–31.5| night_shift_08_final_wave.png                | 第十夜,最后的冲击             | Night ten. The last wave.     | BGM peak        |
| 8  | 31.5–36.0| night_shift_09_success.png                   | 守住了                        | You held.                     | BGM             |
| 9  | 36.0–40.5| night_shift_10_failure.png                   | 失守,也会有报告              | A lost night still gets a report. | BGM soften   |
| 10 | 40.5–45.0| night_shift_11_medbay_treating.png (extra)   | Nora 和 Elias 会累,会犯错   | Nora and Elias tire. They miss. | BGM             |
| 11 | 45.0–50.0| night_shift_05_medbay.png                    | 信任、暴露、资源,三个数字    | Trust. Exposure. Stores. Three numbers. | BGM             |
| 12 | 50.0–54.0| night_shift_17_final.png                     | 第一章,十夜                  | Chapter one. Ten nights.      | BGM fade        |
| 13 | 54.0–58.0| title card (logo overlay on dark)            | 《末日电台:旧体育馆守夜》     | Last Radio: Old Stadium Watch | BGM hold + fade |
| 14 | 58.0–59.5| black                                        | (Steam page URL, small)       | (Steam page URL, small)       | silence         |

## Text styling (drawtext args)

```
fontfile=assets/fonts/NotoSansCJKsc-Regular.otf
fontsize=46
fontcolor=white:alpha=0.95
box=1:boxcolor=black@0.55
boxborderw=18
x=(w-text_w)/2
y=h-90
```

## ffmpeg assembly pipeline

1. Render each segment as still-image-with-caption MP4 (5 sec, 30 fps).
   - `ffmpeg -loop 1 -framerate 30 -t 5 -i frame.png -vf "drawtext=..." -c:v libx264 -pix_fmt yuv420p -r 30 seg_NN.mp4`
2. Concatenate via concat demuxer.
3. Mux BGM, fade in 0→5s, fade out 55→59.5s.
4. Output final `trailer_60s.mp4`.

## Localization

Captions live in two parallel drawtext filter graphs (`captions_zh.txt`,
`captions_en.txt`). The pipeline renders both variants:
`trailer_60s_zh.mp4`, `trailer_60s_en.mp4`. Steam lets you upload two
trailers and choose which to show per locale.
