#!/usr/bin/env node
// bin/postinstall.js
// Runs automatically after `npm install skill-tags`.
// Launches interactive setup wizard on first install; re-syncs on reinstall.
// Falls back gracefully for non-interactive environments (CI, piped input).
// Never throws — a failed postinstall should never break npm install.

'use strict';

const path = require('path');
const fs = require('fs');
const os = require('os');

if (process.platform === 'win32') {
  process.exit(0);
}

const HOME = os.homedir();
const isGlobal = process.env.npm_config_global === 'true';
const SYNC_SCRIPT = path.join(__dirname, '..', 'sync.sh');
const WRAPPER_MARKER = '# ─── skill-tags / Cursor Skill Command Sync';

function isAlreadyConfigured() {
  if (isGlobal) {
    const shellName = path.basename(process.env.SHELL || 'bash');
    let rcFile;
    if (shellName === 'zsh') rcFile = path.join(HOME, '.zshrc');
    else if (process.platform === 'darwin') rcFile = path.join(HOME, '.bash_profile');
    else rcFile = path.join(HOME, '.bashrc');

    try {
      return fs.readFileSync(rcFile, 'utf-8').includes(WRAPPER_MARKER);
    } catch {
      return false;
    }
  }

  try {
    const pkg = JSON.parse(fs.readFileSync(path.join(process.cwd(), 'package.json'), 'utf-8'));
    return pkg.scripts?.skills === 'st-skills';
  } catch {
    return false;
  }
}

function runSync() {
  if (!fs.existsSync(SYNC_SCRIPT)) return;
  const { spawnSync } = require('child_process');
  spawnSync('bash', [SYNC_SCRIPT], { stdio: 'inherit' });
}

async function main() {
  if (isAlreadyConfigured()) {
    if (isGlobal) {
      console.log('\n  skill-tags: re-syncing...\n');
      runSync();
    } else {
      console.log('\n  skill-tags: already configured.\n');
    }
    return;
  }

  try {
    const runSetup = require('./setup');
    await runSetup();
  } catch (err) {
    if (err.name === 'ExitPromptError') {
      console.log();
      return;
    }
    if (isGlobal) {
      console.log('\n  skill-tags: running initial sync...\n');
      runSync();
      console.log('  To configure auto-sync, run: skill-tags --setup\n');
    } else {
      console.log('\n  skill-tags installed as a project dependency.');
      console.log('  Run setup to configure: npx skill-tags --setup\n');
    }
  }
}

main();
