#!/usr/bin/env node
// bin/st-skills.js
// Project-level skills wrapper: runs npx skills and auto-syncs project-skill-tags.md on add/remove/update.

'use strict';

const { spawnSync } = require('child_process');
const path = require('path');

const args = process.argv.slice(2);
const subcommand = args[0];

// Run npx skills with all forwarded arguments
const result = spawnSync('npx', ['skills', ...args], { stdio: 'inherit', shell: false });

if (result.error) {
  console.error(`\n  st-skills: failed to run npx skills — ${result.error.message}\n`);
  process.exit(1);
}

const exitCode = result.status ?? 1;

// Auto-sync project-skill-tags.md on successful mutating subcommands
if (['add', 'remove', 'update'].includes(subcommand) && exitCode === 0) {
  const syncResult = spawnSync(
    'node',
    [path.join(__dirname, 'skill-tags.js'), '--local'],
    { stdio: 'inherit', cwd: process.cwd() }
  );

  if (syncResult.error) {
    console.error(`\n  st-skills: sync failed — ${syncResult.error.message}\n`);
  }
}

process.exit(exitCode);
