#!/usr/bin/env node
// bin/skill-tags.js
// CLI entry point for skill-tags. Spawns sync.sh with bash and passes all args through.

'use strict';

const { spawnSync } = require('child_process');
const path = require('path');
const fs = require('fs');

const VERSION = require('../package.json').version;

// Handle --version before delegating to bash
if (process.argv.includes('--version') || process.argv.includes('-v')) {
  console.log(`skill-tags v${VERSION}`);
  process.exit(0);
}

// Windows is not supported (requires bash)
if (process.platform === 'win32') {
  console.error('skill-tags requires bash and is not supported on Windows.');
  console.error('Consider using WSL (Windows Subsystem for Linux) instead.');
  process.exit(1);
}

// Locate sync.sh bundled alongside this package
const syncScript = path.join(__dirname, '..', 'sync.sh');

if (!fs.existsSync(syncScript)) {
  console.error(`skill-tags: sync.sh not found at ${syncScript}`);
  console.error('Try reinstalling: npm install -g skill-tags');
  process.exit(1);
}

// Pass all CLI arguments through to sync.sh
const args = process.argv.slice(2);
const result = spawnSync('bash', [syncScript, ...args], { stdio: 'inherit' });

if (result.error) {
  console.error(`skill-tags: failed to run bash — ${result.error.message}`);
  process.exit(1);
}

process.exit(result.status ?? 0);
