"""Find what part of the prompt breaks spawn."""
import subprocess
import json

MAVIS_BIN = r"C:\Users\Administrator\.mavis\bin\mavis.cmd"
MY_SID = "mvs_df89daf040574ffab753792bfa164050"

# Test progressively with content that includes ** markdown
tests = [
    ("plain", "Just plain text without any markdown"),
    ("em-dash", "Has em dash — and apostrophe '"),
    ("backtick", "Has backtick `code`"),
    ("bold", "Has bold **text** here"),
    ("italic", "Has italic *text* here"),
    ("all", "All: — em, `code`, **bold**, *italic*, 'apos', \\n escape"),
    ("asterisk2", "Two asterisks ** only"),
    ("asterisk1", "One asterisk * only"),
]

for label, prompt in tests:
    spec = {"agent": "general", "prompt": prompt}
    content = json.dumps(spec, ensure_ascii=False)
    print(f"\n=== {label} (len {len(content)}) ===")
    r = subprocess.run(
        [MAVIS_BIN, "communication", "send",
         "--from", MY_SID, "--to", MY_SID,
         "--command", "spawn",
         "--content", content],
        capture_output=True, text=True, shell=False,
    )
    out_short = r.stdout[:150].replace("\n", " ")
    err_short = r.stderr[:150].replace("\n", " ")
    print(f"  out: {out_short}")
    print(f"  err: {err_short}")
    print(f"  code: {r.returncode}")