#!/usr/bin/env node
// bin/postinstall.js
// Runs automatically after `npm install -g skill-tags`.
// Performs an initial sync of any already-installed skills.
// Never throws — a failed postinstall should never break npm install.

'use strict';

const { spawnSync } = require('child_process');
const path = require('path');
const fs = require('fs');

// Skip entirely on Windows
if (process.platform === 'win32') {
  process.exit(0);
}

// Skip on local (non-global) installs to avoid running on every `npm install`
// in a project. npm sets npm_config_global=true for -g installs.
if (process.env.npm_config_global !== 'true') {
  process.exit(0);
}

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
