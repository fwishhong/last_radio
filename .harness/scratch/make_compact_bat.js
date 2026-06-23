const fs = require('fs');
const cp = require('child_process');

const data = JSON.parse(fs.readFileSync(process.argv[2], 'utf8'));
const compact = JSON.stringify(data); // single line, no whitespace
console.error('Compact length:', compact.length);
console.error('First 80:', compact.substring(0, 80));

const batPath = process.argv[2] + '.compact.bat';
const batContent = '@echo off\r\ncall mavis communication send --from mvs_df89daf040574ffab753792bfa164050 --to mvs_df89daf040574ffab753792bfa164050 --command spawn --content "' + compact.replace(/"/g, '""') + '"\r\n';
fs.writeFileSync(batPath, batContent);
console.error('Bat path:', batPath);
console.error('Bat length:', batContent.length);