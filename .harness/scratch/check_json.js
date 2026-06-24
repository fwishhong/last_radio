const fs = require('fs');
const data = JSON.parse(fs.readFileSync('.harness/scratch/spawn_artist_tasks34.json', 'utf8'));
const matches = data.prompt.match(/"/g);
console.log('Unescaped quote count:', matches ? matches.length : 0);

// Try to parse the re-stringified JSON to confirm validity
const compact = JSON.stringify(data);
console.log('Compact length:', compact.length);
try {
  JSON.parse(compact);
  console.log('Compact JSON parses OK');
} catch (e) {
  console.log('Compact JSON INVALID:', e.message);
}

// Show first 300 chars of compact
console.log('Compact first 300:', compact.substring(0, 300));