"""Test & specifically."""
import subprocess
import json

MAVIS_BIN = r"C:\Users\Administrator\.mavis\bin\mavis.cmd"
MY_SID = "mvs_df89daf040574ffab753792bfa164050"

tests = [
    ("no-amp", "Just plain text"),
    ("amp", "Has ampersand & here"),
    ("amp2", "Two ampersands && here"),
    ("amp-backtick", "Backtick & code & mix"),
]

for label, prompt in tests:
    spec = {"agent": "general", "prompt": prompt}
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
    print(f"  {label} (len {len(content)}): {status} | {err_preview}")