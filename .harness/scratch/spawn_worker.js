const fs = require('fs');
const cp = require('child_process');

const args = process.argv.slice(2);
const jsonPath = args[0];

const data = fs.readFileSync(jsonPath, 'utf8');
console.log('Content length:', data.length);
console.log('Content first 100:', data.substring(0, 100));

const child = cp.spawnSync('mavis', [
  'communication', 'send',
  '--from', 'mvs_df89daf040574ffab753792bfa164050',
  '--to', 'mvs_df89daf040574ffab753792bfa164050',
  '--command', 'spawn',
  '--content', data
], { encoding: 'utf8', maxBuffer: 50 * 1024 * 1024 });

console.log('=== error ===');
console.log(child.error);
console.log('=== stdout ===');
console.log(child.stdout);
console.log('=== stderr ===');
console.log(child.stderr);
console.log('=== status ===');
console.log(child.status);
console.log('=== signal ===');
console.log(child.signal);