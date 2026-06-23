"""Use JSON unicode escape for &."""
import subprocess
import json

MAVIS_BIN = r"C:\Users\Administrator\.mavis\bin\mavis.cmd"
MY_SID = "mvs_df89daf040574ffab753792bfa164050"

spec = {"agent": "general", "prompt": "Has ampersand \\u0026 and double \\u0026\\u0026 here"}
content = json.dumps(spec, ensure_ascii=False)
print("Content:", content)
print("Contains literal &:", "&" in content)

r = subprocess.run(
    [MAVIS_BIN, "communication", "send",
     "--from", MY_SID, "--to", MY_SID,
     "--command", "spawn",
     "--content", content],
    capture_output=True, text=True, shell=False,
)
print("out:", r.stdout[:300])
print("err:", r.stderr[:300])
print("code:", r.returncode)