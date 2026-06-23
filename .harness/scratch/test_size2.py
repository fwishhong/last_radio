"""Binary search for size threshold."""
import subprocess
import json

MAVIS_BIN = r"C:\Users\Administrator\.mavis\bin\mavis.cmd"
MY_SID = "mvs_df89daf040574ffab753792bfa164050"

with open(".harness/scratch/spawn_artist_tasks34.json", "r", encoding="utf-8") as f:
    spec = json.load(f)

# Truncate prompt to test size threshold
original_prompt = spec["prompt"]
print(f"Original prompt length: {len(original_prompt)}")

# Test with progressively larger slices of the original prompt
for size in [500, 1000, 2000, 3000, 4000, len(original_prompt)]:
    test_spec = {"agent": "general", "prompt": original_prompt[:size]}
    content = json.dumps(test_spec, ensure_ascii=False)
    print(f"\n=== Size {size}, content len {len(content)} ===")
    r = subprocess.run(
        [MAVIS_BIN, "communication", "send",
         "--from", MY_SID, "--to", MY_SID,
         "--command", "spawn",
         "--content", content],
        capture_output=True, text=True, shell=False,
    )
    out_short = r.stdout[:200].replace("\n", " ")
    err_short = r.stderr[:200].replace("\n", " ")
    print(f"  out: {out_short}")
    print(f"  err: {err_short}")
    print(f"  code: {r.returncode}")