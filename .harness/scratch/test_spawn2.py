"""Test spawn with content containing internal spaces."""
import subprocess

content = '{"agent":"general","prompt":"hello with spaces test"}'
print('Content:', repr(content))
print('Length:', len(content))

r = subprocess.run(
    [r'C:\Users\Administrator\.mavis\bin\mavis.cmd', 'communication', 'send',
     '--from', 'mvs_df89daf040574ffab753792bfa164050',
     '--to', 'mvs_df89daf040574ffab753792bfa164050',
     '--command', 'spawn',
     '--content', content],
    capture_output=True, text=True, shell=False,
)
print('out:', r.stdout)
print('err:', r.stderr)
print('code:', r.returncode)