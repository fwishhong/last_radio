"""Replace & | < > ^ with JSON unicode escapes to survive cmd."""
import re
import subprocess
import json
import sys

MAVIS_BIN = r"C:\Users\Administrator\.mavis\bin\mavis.cmd"
MY_SID = "mvs_df89daf040574ffab753792bfa164050"

# Cmd-special chars that need escaping
CMD_SPECIAL = {
    "&": "\\u0026",
    "|": "\\u007c",
    "<": "\\u003c",
    ">": "\\u003e",
    "^": "\\u005e",
}

def escape_for_cmd(json_str: str) -> str:
    """Replace literal cmd-special chars with JSON unicode escapes."""
    # Only escape chars that are NOT inside string values (i.e., not the JSON's structural quotes).
    # Strategy: split on JSON's structural chars and only escape within string values.
    # Simpler approach: only escape chars that appear inside the 'prompt' string value.
    # We can't easily tell where strings are without parsing. Use a heuristic.
    # The cmd-special chars in structural JSON (keys, separators) are extremely rare.
    # So escape all of them — the JSON parser will decode the escapes correctly.
    result = json_str
    for char, escape in CMD_SPECIAL.items():
        result = result.replace(char, escape)
    return result

# Test
json_path = sys.argv[1]
with open(json_path, "r", encoding="utf-8") as f:
    spec = json.load(f)

content = json.dumps(spec, ensure_ascii=False)
content_safe = escape_for_cmd(content)
print(f"Original content length: {len(content)}")
print(f"Safe content length: {len(content_safe)}")
print(f"Contains literal &: {'&' in content_safe}")
print(f"Contains \\\\u0026: {chr(92)+'u0026' in content_safe}")

r = subprocess.run(
    [MAVIS_BIN, "communication", "send",
     "--from", MY_SID, "--to", MY_SID,
     "--command", "spawn",
     "--content", content_safe],
    capture_output=True, shell=False,
    encoding="utf-8", errors="replace",
)
print("out:", r.stdout[:400])
print("err:", r.stderr[:300])
print("code:", r.returncode)