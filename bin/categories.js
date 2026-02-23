#!/usr/bin/env node
// bin/categories.js
// Interactive category wizard using @inquirer/prompts for polished checkbox UI.
// Reads skill-tags.md as the keyword search source (runs sync.sh first if needed).

'use strict';

const { checkbox, select, input, confirm } = require('@inquirer/prompts');
const { spawnSync } = require('child_process');
const path = require('path');
const fs = require('fs');
const os = require('os');

const HOME = os.homedir();
const CATEGORIES_CONFIG = path.join(HOME, '.cursor', 'skill-tags-categories.conf');
const COMMANDS_DIR = path.join(HOME, '.cursor', 'commands');
const SKILL_TAGS_FILE = path.join(COMMANDS_DIR, 'skill-tags.md');
const SYNC_SCRIPT = path.join(__dirname, '..', 'sync.sh');

const PREDEFINED_CATEGORIES = [
  'frontend',
  'backend',
  'database',
  'testing',
  'design',
  'accessibility',
  'performance',
  'ai-agents',
  'devops',
  'marketing',
  'mobile',
  'documentation',
];

// Only tool names, framework names, domain acronyms, and specific compound terms.
// No generic English words (server, component, cache, query, test, etc.).
const CATEGORY_KEYWORDS = {
  frontend: [
    'frontend',
    'react', 'next', 'nextjs', 'vue', 'nuxt', 'svelte', 'sveltekit', 'angular',
    'tailwind', 'css', 'sass', 'html', 'jsx', 'tsx',
    'shadcn', 'radix', 'vite', 'webpack', 'turbopack',
    'framer-motion', 'container-query', 'server-component', 'rsc', 'app-router',
  ],
  backend: [
    'graphql', 'trpc', 'expressjs', 'fastify', 'nestjs', 'hono',
    'fastapi', 'django', 'laravel',
    'webhook', 'websocket', 'jwt', 'oauth', 'better-auth',
    'stripe', 'payment', 'serverless', 'edge-function', 'lambda',
  ],
  database: [
    'postgres', 'postgresql', 'mysql', 'sqlite', 'mongodb', 'redis',
    'drizzle', 'prisma', 'knex',
    'supabase', 'planetscale', 'neon', 'turso',
    'sql', 'orm', 'row-level-security', 'rls',
  ],
  testing: [
    'vitest', 'jest', 'mocha', 'playwright', 'cypress', 'puppeteer', 'selenium',
    'test-driven', 'tdd', 'bdd', 'e2e', 'end-to-end',
    'webapp-testing', 'browser-testing',
  ],
  design: [
    'figma', 'sketch', 'adobe-xd',
    'typography', 'font-pairing',
    'glassmorphism', 'neumorphism', 'brutalism', 'skeuomorphism', 'flat-design',
    'dark-mode', 'design-token', 'design-system', 'style-guide', 'brand-guideline',
    'interface-design', 'ux-audit', 'ux-review', 'web-design-guideline', 'design-pattern',
  ],
  accessibility: [
    'accessibility', 'a11y', 'aria', 'wcag',
    'screen-reader', 'voiceover', 'nvda', 'jaws',
    'reduced-motion', 'prefers-reduced-motion', 'semantic-html',
    'keyboard-navigation', 'focus-trap',
  ],
  performance: [
    'lighthouse', 'web-vitals', 'core-web-vitals', 'lcp', 'cls', 'inp', 'fcp', 'ttfb',
    'lazy-load', 'code-split', 'tree-shake',
    'stale-while-revalidate', 'isr',
    'webp', 'avif', 'bundle-size', 'virtual-list',
    'react-doctor',
  ],
  'ai-agents': [
    'subagent', 'multi-agent', 'parallel-agent',
    'skill-creator', 'skill-install', 'brainstorm',
    'mcp', 'cursor', 'claude-code', 'claude-md', 'cursor-rule',
    'browser-automation', 'browser-use', 'worktree',
    'code-review', 'debugging', 'verification',
    'llm', 'openai', 'anthropic', 'gemini',
  ],
  devops: [
    'netlify', 'railway', 'fly-io', 'heroku',
    'docker', 'dockerfile', 'docker-compose', 'kubernetes', 'k8s',
    'cicd', 'github-actions', 'gitlab-ci', 'circleci',
    'terraform', 'pulumi',
    'nginx', 'caddy',
    'deploy', 'deployment', 'rollback',
  ],
  marketing: [
    'seo', 'seo-audit', 'meta-tag', 'open-graph', 'twitter-card', 'json-ld', 'schema-markup',
    'sitemap', 'robots-txt', 'structured-data',
    'google-analytics', 'plausible', 'posthog',
    'programmatic-seo', 'copywriting', 'a-b-test',
  ],
  mobile: [
    'react-native', 'expo', 'expo-router',
    'flutter', 'dart', 'swiftui', 'kotlin', 'jetpack-compose',
    'ios', 'android',
    'eas-build', 'eas-submit', 'reanimated',
  ],
  documentation: [
    'markdown', 'mdx', 'readme', 'changelog',
    'openapi', 'swagger', 'typedoc', 'jsdoc',
    'docusaurus', 'nextra', 'mintlify', 'gitbook', 'vitepress',
    'github-flavored-markdown', 'gfm',
  ],
};

// ─── skill-tags.md reader ────────────────────────────────────────────────────

function ensureSkillTagsFile() {
  if (fs.existsSync(SKILL_TAGS_FILE)) return;
  console.log('  skill-tags.md not found — running initial sync...\n');
  spawnSync('bash', [SYNC_SCRIPT], { stdio: 'inherit' });
}

function loadSkillsFromIndex() {
  const content = fs.readFileSync(SKILL_TAGS_FILE, 'utf-8');
  const skills = [];

  const sections = content.split(/^### /m);
  for (const section of sections) {
    if (!section.trim()) continue;

    const lines = section.split('\n');
    const title = lines[0].trim();
    if (!title) continue;

    let skillPath = '';
    let description = '';

    for (let i = 1; i < lines.length; i++) {
      const line = lines[i].trim();
      if (line.startsWith('`') && line.endsWith('`') && !skillPath) {
        skillPath = line.slice(1, -1);
      } else if (line && !line.startsWith('#') && !line.startsWith('<!--') && !description) {
        description = line;
      }
    }

    if (!skillPath) continue;

    const name = path.basename(skillPath);
    // Full section text, lowercased with hyphens normalized to spaces
    const searchText = section.toLowerCase().replace(/-/g, ' ');

    skills.push({ name, path: skillPath, title, description: description || '', searchText });
  }

  return skills.sort((a, b) => a.name.localeCompare(b.name));
}

// ─── Keyword matching ────────────────────────────────────────────────────────

function escapeRegex(str) {
  return str.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

function matchKeywords(skill, category) {
  const keywords = CATEGORY_KEYWORDS[category] || [];
  if (keywords.length === 0) return null;

  for (const kw of keywords) {
    const normalized = kw.toLowerCase().replace(/-/g, ' ');
    const escaped = escapeRegex(normalized);
    // Suffix expansion: plurals (s/es), past tense (ed), gerunds (ing),
    // agent nouns (er), and nominalizations (ment) — e.g. brainstorm→brainstorming
    const pattern = new RegExp('\\b' + escaped + '(?:s|es|ed|ing|er|ment)?\\b');
    if (pattern.test(skill.searchText)) {
      return { reason: kw };
    }
  }

  return null;
}

// ─── Config file I/O ─────────────────────────────────────────────────────────

function readConfig() {
  const config = {};
  if (!fs.existsSync(CATEGORIES_CONFIG)) return config;
  const content = fs.readFileSync(CATEGORIES_CONFIG, 'utf-8');
  for (const line of content.split('\n')) {
    if (line.startsWith('#') || !line.includes('=')) continue;
    const idx = line.indexOf('=');
    const cat = line.slice(0, idx).trim();
    const skillList = line.slice(idx + 1).trim();
    if (cat) config[cat] = skillList ? skillList.split(',').filter(Boolean) : [];
  }
  return config;
}

function writeConfig(config) {
  const lines = ['# skill-tags category config — edit with: skill-tags --categories'];
  for (const [cat, skills] of Object.entries(config)) {
    lines.push(`${cat}=${skills.join(',')}`);
  }
  fs.mkdirSync(path.dirname(CATEGORIES_CONFIG), { recursive: true });
  fs.writeFileSync(CATEGORIES_CONFIG, lines.join('\n') + '\n');
}

function toTitleCase(str) {
  return str.replace(/[-_]/g, ' ').replace(/\b\w/g, c => c.toUpperCase());
}

// ─── Wizard actions ──────────────────────────────────────────────────────────

async function addCategories(skills, config) {
  const existing = new Set(Object.keys(config));
  const available = PREDEFINED_CATEGORIES.filter(c => !existing.has(c));

  let selected = [];
  if (available.length > 0) {
    selected = await checkbox({
      message: 'Select categories to add (space to toggle)',
      choices: available.map(c => ({ name: toTitleCase(c), value: c })),
      pageSize: 14,
    });
  } else {
    console.log('\n  All predefined categories already exist.');
  }

  const custom = await input({
    message: 'Custom category name (blank to skip):',
  });

  if (custom.trim()) {
    const normalized = custom.trim().toLowerCase()
      .replace(/[^a-z0-9-]/g, '-')
      .replace(/-+/g, '-')
      .replace(/^-|-$/g, '');
    if (normalized && !existing.has(normalized)) {
      selected.push(normalized);
    } else if (existing.has(normalized)) {
      console.log(`  "${normalized}" already exists — use Edit instead.`);
    }
  }

  if (selected.length === 0) {
    console.log('  No categories selected.\n');
    return;
  }

  for (const cat of selected) {
    const matched = skills.filter(s => matchKeywords(s, cat));
    config[cat] = matched.map(s => s.name);
    console.log(`  ✓ ${toTitleCase(cat)}: ${matched.length} skill(s) auto-assigned\n`);
  }
}

async function editCategory(skills, config) {
  const cats = Object.keys(config);
  if (cats.length === 0) {
    console.log('  No categories yet. Add one first.\n');
    return;
  }

  const cat = await select({
    message: 'Which category to edit?',
    choices: cats.map(c => ({
      name: `${toTitleCase(c)} (${config[c].length} skills)`,
      value: c,
    })),
  });

  const matched = skills.filter(s => matchKeywords(s, cat));
  config[cat] = matched.map(s => s.name);
  console.log(`  ✓ Re-generated ${toTitleCase(cat)}: ${matched.length} skill(s) auto-assigned\n`);
}

async function deleteCategory(config) {
  const cats = Object.keys(config);
  if (cats.length === 0) {
    console.log('  No categories yet.\n');
    return;
  }

  const cat = await select({
    message: 'Which category to delete?',
    choices: cats.map(c => ({
      name: `${toTitleCase(c)} (${config[c].length} skills)`,
      value: c,
    })),
  });

  const yes = await confirm({
    message: `Delete "${cat}" and its generated command file?`,
    default: false,
  });

  if (yes) {
    delete config[cat];
    const genFile = path.join(COMMANDS_DIR, `skills-${cat}.md`);
    try { fs.unlinkSync(genFile); } catch {}
    console.log(`  ✓ Deleted: ${cat}\n`);
  }
}

function printCurrentCategories(config) {
  const cats = Object.keys(config);
  if (cats.length === 0) {
    console.log('  Categories: (none yet)\n');
    return;
  }
  console.log('  Current categories:');
  for (const cat of cats) {
    console.log(`    • ${toTitleCase(cat)} (${config[cat].length} skills)`);
  }
  console.log();
}

// ─── Main loop ───────────────────────────────────────────────────────────────

async function main() {
  console.log('\n  skill-tags: category wizard\n');

  ensureSkillTagsFile();

  console.log('  Loading skills from skill-tags.md...');
  const skills = loadSkillsFromIndex();
  console.log(`  Found ${skills.length} skill(s)\n`);

  const config = readConfig();

  while (true) {
    printCurrentCategories(config);

    const action = await select({
      message: 'What would you like to do?',
      choices: [
        { name: 'Add categories', value: 'add' },
        { name: 'Edit a category', value: 'edit' },
        { name: 'Delete a category', value: 'delete' },
        { name: 'Save & generate files', value: 'save' },
        { name: 'Quit without saving', value: 'quit' },
      ],
    });

    switch (action) {
      case 'add':
        await addCategories(skills, config);
        break;
      case 'edit':
        await editCategory(skills, config);
        break;
      case 'delete':
        await deleteCategory(config);
        break;
      case 'save': {
        writeConfig(config);
        console.log('\n  Config saved. Running sync...\n');
        const result = spawnSync('bash', [SYNC_SCRIPT], { stdio: 'inherit' });
        if (result.error) {
          console.error(`  Error running sync: ${result.error.message}`);
        }
        process.exit(result.status ?? 0);
      }
      case 'quit':
        process.exit(0);
    }
  }
}

main().catch(err => {
  if (err.name === 'ExitPromptError') {
    console.log('\n');
    process.exit(0);
  }
  console.error('Error:', err.message);
  process.exit(1);
});
