#!/usr/bin/env node
// bin/postinstall.js
// Runs automatically after `npm install skill-tags`.
// Global installs: perform initial sync. Local installs: print setup guidance.
// Never throws — a failed postinstall should never break npm install.

'use strict';

const { spawnSync } = require('child_process');
const path = require('path');
const fs = require('fs');

// Skip entirely on Windows
if (process.platform === 'win32') {
  process.exit(0);
}

const isGlobal = process.env.npm_config_global === 'true';

if (!isGlobal) {
  // Project (local) install — print setup guidance and exit cleanly
  console.log('\n  skill-tags installed as a project dependency.');
  console.log('  Run setup to add the "skills" npm script to your package.json:\n');
  console.log('    npx skill-tags --setup\n');
  process.exit(0);
}

// ─── Global install: run initial sync ────────────────────────────────────────

const syncScript = path.join(__dirname, '..', 'sync.sh');

if (!fs.existsSync(syncScript)) {
  process.exit(0);
}

console.log('\n  skill-tags: running initial sync...\n');

try {
  const result = spawnSync('bash', [syncScript], { stdio: 'inherit' });
  if (result.error) throw result.error;
} catch (_) {
  // Never fail the install
}

console.log('  To auto-sync after every `skills add`, run:');
console.log('    skill-tags --setup\n');

process.exit(0);
