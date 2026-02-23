#!/usr/bin/env node
// bin/setup.js
// Interactive setup wizard: global/project install mode + auto/manual sync preference.

'use strict';

const { spawnSync } = require('child_process');
const path = require('path');
const fs = require('fs');
const os = require('os');

const HOME = os.homedir();
const SYNC_SCRIPT = path.join(__dirname, '..', 'sync.sh');
const WRAPPER_MARKER = '# ─── skill-tags / Cursor Skill Command Sync';

module.exports = async function runSetup() {
  const { select, confirm } = require('@inquirer/prompts');

  console.log('\n  skill-tags: setup\n');

  const isGlobal = process.env.npm_config_global === 'true';

  const mode = await select({
    message: 'How are you using skill-tags?',
    choices: [
      {
        name: 'Global  — add skills() wrapper to shell profile (recommended for most users)',
        value: 'global',
      },
      {
        name: 'Project — add "skills" npm script to this project\'s package.json',
        value: 'project',
      },
    ],
    default: isGlobal ? 'global' : 'project',
  });

  const syncMode = await select({
    message: 'How should skill-tags sync?',
    choices: [
      {
        name: 'Auto (recommended) — sync automatically whenever you add or remove a skill',
        value: 'auto',
      },
      {
        name: 'Manual — run skill-tags yourself to sync when needed',
        value: 'manual',
      },
    ],
    default: 'auto',
  });

  if (mode === 'global') {
    await setupGlobal(confirm, syncMode);
  } else {
    await setupProject(confirm, syncMode);
  }
};

// ─── Global setup ─────────────────────────────────────────────────────────────

async function setupGlobal(confirm, syncMode) {
  const shellName = path.basename(process.env.SHELL || 'bash');
  let rcFile;
  if (shellName === 'zsh') rcFile = path.join(HOME, '.zshrc');
  else if (process.platform === 'darwin') rcFile = path.join(HOME, '.bash_profile');
  else rcFile = path.join(HOME, '.bashrc');

  const displayRc = rcFile.replace(HOME, '~');

  if (syncMode === 'manual') {
    console.log('\n  Manual sync selected.');
    console.log('  Run skill-tags at any time to regenerate ~/.cursor/commands/skill-tags.md\n');
    console.log('  Running initial sync...\n');
    spawnSync('bash', [SYNC_SCRIPT], { stdio: 'inherit' });
    console.log(`\n  Done! Run skill-tags manually to re-sync.\n`);
    return;
  }

  // Auto sync: add shell wrapper
  let alreadyInstalled = false;
  try {
    const content = fs.readFileSync(rcFile, 'utf-8');
    if (content.includes(WRAPPER_MARKER)) alreadyInstalled = true;
  } catch {}

  if (alreadyInstalled) {
    console.log(`\n  ✓ Shell wrapper already installed in ${displayRc}\n`);
    process.exit(0);
  }

  console.log(`\n  This will add a skills() shell wrapper to ${displayRc}`);
  console.log(`  It auto-syncs skill-tags.md after every skills add/remove.\n`);

  const yes = await confirm({
    message: `Add the wrapper to ${displayRc}?`,
    default: true,
  });

  if (!yes) {
    console.log('\n  Skipped.\n');
    process.exit(0);
  }

  const syncPath = fs.existsSync(path.join(HOME, '.cursor', 'sync-skill-commands.sh'))
    ? path.join(HOME, '.cursor', 'sync-skill-commands.sh')
    : SYNC_SCRIPT;

  const wrapper = `
${WRAPPER_MARKER} ────────────────────────────────────────────────
# Wraps \`npx skills\` to auto-generate skill-tags.md after install/removal.
# Run manually: skill-tags   (or: bash ${syncPath})
function skills() {
  npx skills "$@"
  local exit_code=$?
  if [[ "$1" == "add" || "$1" == "remove" ]] && [[ $exit_code -eq 0 ]]; then
    bash "${syncPath}"
  fi
  return $exit_code
}
# ─────────────────────────────────────────────────────────────────────────────
`;

  try {
    fs.appendFileSync(rcFile, wrapper);
  } catch (err) {
    console.error(`\n  Failed to write to ${displayRc}: ${err.message}\n`);
    process.exit(1);
  }

  console.log(`\n  ✓ Added skills() wrapper to ${displayRc}`);
  console.log(`  Reload with: source ${displayRc}\n`);
}

// ─── Project setup ────────────────────────────────────────────────────────────

async function setupProject(confirm, syncMode) {
  const pkgPath = path.join(process.cwd(), 'package.json');

  if (!fs.existsSync(pkgPath)) {
    console.error('\n  No package.json found in current directory.');
    console.error('  Run skill-tags --setup from your project root.\n');
    process.exit(1);
  }

  let pkg;
  try {
    pkg = JSON.parse(fs.readFileSync(pkgPath, 'utf-8'));
  } catch (err) {
    console.error(`\n  Failed to read package.json: ${err.message}\n`);
    process.exit(1);
  }

  const scripts = pkg.scripts || {};

  if (syncMode === 'manual') {
    console.log('\n  Manual sync selected.');
    console.log('  Run skill-tags --local at any time to regenerate .cursor/commands/project-skill-tags.md\n');
    console.log('  Running initial project sync...\n');
    spawnSync(
      'node',
    [path.join(__dirname, 'skill-tags.js'), '--local'],
    { stdio: 'inherit', cwd: process.cwd() }
  );
  console.log(`\n  Done! Run skill-tags --local manually to re-sync.\n`);
    return;
  }

  // Auto sync: add "skills" npm script
  if (scripts.skills === 'st-skills') {
    console.log('\n  ✓ Already configured — "skills": "st-skills" is in package.json\n');
    console.log('  Add a skill:  npm run skills add <owner/repo/skill-name>');
    console.log('  Remove:       npm run skills remove <owner/repo/skill-name>\n');
    process.exit(0);
  }

  console.log('\n  This will add a "skills" script to your package.json:');
  console.log('    "scripts": { "skills": "st-skills" }');
  console.log('\n  Then use:  npm run skills add <owner/repo/skill-name>');
  console.log('  Auto-syncs .cursor/commands/project-skill-tags.md after every add/remove.\n');

  const yes = await confirm({
    message: 'Add the "skills" script to package.json?',
    default: true,
  });

  if (!yes) {
    console.log('\n  Skipped.\n');
    process.exit(0);
  }

  pkg.scripts = { ...scripts, skills: 'st-skills' };

  try {
    fs.writeFileSync(pkgPath, JSON.stringify(pkg, null, 2) + '\n', 'utf-8');
  } catch (err) {
    console.error(`\n  Failed to write package.json: ${err.message}\n`);
    process.exit(1);
  }

  console.log('\n  ✓ Added "skills": "st-skills" to package.json');
  console.log('\n  Running initial project sync...\n');

  const result = spawnSync(
    'node',
    [path.join(__dirname, 'skill-tags.js'), '--local'],
    { stdio: 'inherit', cwd: process.cwd() }
  );

  if (result.error) {
    console.error(`\n  Warning: initial sync failed — ${result.error.message}`);
  }

  console.log('\n  Setup complete!\n');
  console.log('  Add a skill:   npm run skills add <owner/repo/skill-name>');
  console.log('  Remove:        npm run skills remove <owner/repo/skill-name>');
  console.log('  Manual sync:   skill-tags --local\n');
}
