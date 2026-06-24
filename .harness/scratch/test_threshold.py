"""Narrow down size threshold for artist-style prompt."""
import subprocess
import json

MAVIS_BIN = r"C:\Users\Administrator\.mavis\bin\mavis.cmd"
MY_SID = "mvs_df89daf040574ffab753792bfa164050"

artist_prompt = "You are filling the **artist rein** role for a small Godot 4.3 game called *Last Radio: Old Stadium Watch*. You're an audio/visual asset owner — NOT a coder. Don't write GDScript or modify scenes. Don't touch gameplay data JSON. Just generate audio assets + a visual capture proof, write the matching .import sidecars, and report back.\\n\\n## Read first\\n- `AGENTS.md` (project root, especially Setup commands and code style sections)\\n- `docs/release_roadmap.md` M5 (art & BGM scope)\\n- `scripts/NightShiftGame.gd` `_load_audio()` (~line 431) and `_play_music()` (~line 456) — these tell you the exact filenames the developer expects\\n- `scripts/NightShiftSfx.gd` (~line 10 `build_all()`) — SFX key namespace\\n- `.harness/reins/artist/agent.md` — your full role definition"

for size in [200, 300, 400, 450, 500, 540, 600]:
    test_prompt = artist_prompt[:size]
    spec = {"agent": "general", "prompt": test_prompt}
    content = json.dumps(spec, ensure_ascii=False)
    r = subprocess.run(
        [MAVIS_BIN, "communication", "send",
         "--from", MY_SID, "--to", MY_SID,
         "--command", "spawn",
         "--content", content],
        capture_output=True, text=True, shell=False,
    )
    status = "PASS" if "delivered" in r.stdout else "FAIL"
    err_preview = r.stderr[:100].replace("\n", " ") if r.stderr else ""
    print(f"  size {size} (content {len(content)}): {status} | {err_preview}")