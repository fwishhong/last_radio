const fs = require('fs');
const data = JSON.parse(fs.readFileSync('.harness/scratch/spawn_artist_tasks34.json', 'utf8'));
const compact = JSON.stringify(data);

// Check for control characters in the compact JSON
for (let i = 0; i < compact.length; i++) {
  const c = compact.charCodeAt(i);
  if (c < 0x20 && c !== 0x09 && c !== 0x0A && c !== 0x0D) {
    console.log(`Found control char at ${i}: 0x${c.toString(16)}`);
  }
}

// Also check for valid JSON parse
try {
  const parsed = JSON.parse(compact);
  console.log('Parse OK, agent:', parsed.agent, 'prompt length:', parsed.prompt.length);
} catch (e) {
  console.log('Parse FAIL:', e.message);
  // Find approximate position
  const m = e.message.match(/position (\d+)/);
  if (m) {
    const pos = parseInt(m[1]);
    console.log('Around pos:', compact.substring(Math.max(0, pos-50), pos+50));
  }
}

// Also check what python wrote
const pyContent = fs.readFileSync('.harness/scratch/_debug_content.json', 'utf8');
console.log('Python content length:', pyContent.length);
console.log('Python content first 200:', pyContent.substring(0, 200));
console.log('Python content matches compact:', pyContent === compact);