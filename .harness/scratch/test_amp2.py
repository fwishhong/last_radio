"""Try shell=True with proper & escaping."""
import subprocess
import json

MAVIS_BIN = r"C:\Users\Administrator\.mavis\bin\mavis.cmd"
MY_SID = "mvs_df89daf040574ffab753792bfa164050"

# Approach: pass content via env var (cmd doesn't process env vars for &)
import os

spec = {"agent": "general", "prompt": "Has ampersand & and double && here"}
content = json.dumps(spec, ensure_ascii=False)
os.environ["SPAWN_CONTENT"] = content

# Build command line using env var reference
# cmd doesn't expand %VAR% in middle of arg string unless cmd /v:on delayed expansion
# Easier: just escape & for cmd
content_escaped = content.replace("&", "^&")

r = subprocess.run(
    f'mavis communication send --from {MY_SID} --to {MY_SID} --command spawn --content "{content_escaped}"',
    capture_output=True, text=True, shell=True,
)
print("out:", r.stdout[:300])
print("err:", r.stderr[:300])
print("code:", r.returncode)