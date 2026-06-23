"""Simple test spawn to verify the spawn mechanism."""
import subprocess
import sys

content = '{"agent":"general","prompt":"hello world test"}'

MAVIS_BIN = r"C:\Users\Administrator\.mavis\bin\mavis.cmd"
r = subprocess.run(
    [MAVIS_BIN, "communication", "send",
     "--from", "mvs_df89daf040574ffab753792bfa164050",
     "--to",   "mvs_df89daf040574ffab753792bfa164050",
     "--command", "spawn",
     "--content", content],
    capture_output=True, text=True, shell=False,
)
print("out:", r.stdout)
print("err:", r.stderr)
print("code:", r.returncode)