"""Find the threshold where spawn breaks."""
import subprocess

MAVIS_BIN = r"C:\Users\Administrator\.mavis\bin\mavis.cmd"
MY_SID = "mvs_df89daf040574ffab753792bfa164050"

# Test with progressively longer content
for size in [100, 500, 1000, 2000, 3000, 4000, 5000]:
    content = '{"agent":"general","prompt":"' + ('x' * (size - 30)) + '"}'
    print(f"\n=== Test size {size}, content len {len(content)} ===")
    r = subprocess.run(
        [MAVIS_BIN, "communication", "send",
         "--from", MY_SID, "--to", MY_SID,
         "--command", "spawn",
         "--content", content],
        capture_output=True, text=True, shell=False,
    )
    print("out:", r.stdout[:200])
    print("err:", r.stderr[:200])
    print("code:", r.returncode)