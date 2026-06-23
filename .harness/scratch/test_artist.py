"""Find what breaks the spawn - full output capture."""
import subprocess
import json

MAVIS_BIN = r"C:\Users\Administrator\.mavis\bin\mavis.cmd"
MY_SID = "mvs_df89daf040574ffab753792bfa164050"

with open(".harness/scratch/spawn_artist_tasks34.json", "r", encoding="utf-8") as f:
    spec = json.load(f)

content = json.dumps(spec, ensure_ascii=False)
print("Full content length:", len(content))

r = subprocess.run(
    [MAVIS_BIN, "communication", "send",
     "--from", MY_SID, "--to", MY_SID,
     "--command", "spawn",
     "--content", content],
    capture_output=True, text=True, shell=False,
)

with open(".harness/scratch/_err.log", "w", encoding="utf-8") as f:
    f.write(r.stderr)
with open(".harness/scratch/_out.log", "w", encoding="utf-8") as f:
    f.write(r.stdout)
print(f"stderr written ({len(r.stderr)} chars), stdout written ({len(r.stdout)} chars)")
print(f"Return code: {r.returncode}")