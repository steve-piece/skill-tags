# skill-tags

Generates consolidated command files (`@skill-tags.md` and custom `@skills-<category>.md` indexes) for all installed Cursor skills. Reference them in any chat to give the agent a complete directory of your available skills, enabling it to autonomously select and apply the right tools for the task.

> **Coming soon:** Stay tuned for a more permanent solution to this problem: I'm developing an open source community called [Cursor Kits](https://cursorkits.com). Cursor Kits is something I started before Cursor launched their [Plugin Marketplace](https://cursor.com/marketplace). It's the same idea, but built for the community (vs integration providers).

If you're interested in contributing to Cursor Kits, please let me know!

---

## Table of Contents

- [Quick Start](#quick-start)
- [Usage](#usage)
- [Categorized Indexes](#categorized-indexes)
- [Agent Setup Prompt](#agent-setup-prompt)
- [Install Options](#install-options)
- [How It Works](#how-it-works)
- [Project-Level Install](#project-level-install)
- [CLI Reference](#cli-reference)
- [Manual Sync](#manual-sync)
- [Skill Sources Scanned](#skill-sources-scanned)
- [Generated File Format](#generated-file-format)
- [How Categorization Works](#how-categorization-works)
- [Uninstall](#uninstall)
- [Requirements](#requirements)
- [License](#license)

---

## Quick Start

### Global (recommended for most users)

1. **Install:** `npm install skill-tags -g`
2. **Setup:** `skill-tags --setup` → choose **Global** → `source ~/.zshrc`
3. **Sync:** `skill-tags` (generates the command file)
4. **Use:** Reference `@skill-tags.md` in any Cursor chat

```bash
npm install skill-tags -g
skill-tags --setup   # choose: Global
source ~/.zshrc
skill-tags
```

### Project-level

1. **Install:** `npm install skill-tags --save-dev`
2. **Setup:** `npx skill-tags --setup` → choose **Project**
3. **Use:** Reference `@project-skill-tags.md` in Cursor chat

```bash
npm install skill-tags --save-dev
npx skill-tags --setup   # choose: Project — adds "skills" script to package.json

npm run skills add owner/repo/skill-name   # adds skill + auto-syncs
```

## Usage

In any Cursor chat, attach the full index of your skills by referencing the generated command file:

- `@skill-tags.md` (global) or `@project-skill-tags.md` (local, from `skill-tags --local`)

Example:

```text
@skill-tags.md Help me refactor this React component to be more performant.
```

The agent will assess the available skills listed in the file, automatically determine which ones are relevant (e.g., `vercel-react-best-practices`), and apply them to your request. If the agent is in **Plan Mode**, it will also proactively reference specific skills to be used in the generated plan and TODOs.

## Categorized Indexes

For more focused context windows, you can group your skills into category-specific index files using the interactive wizard:

```bash
skill-tags --categories
```

This opens an interactive wizard where you can create, edit, and delete categories. Skill assignment is powered by keyword matching against the generated `skill-tags.md` index — all text is lowercased with strict full-word matching and automatic suffix expansion (plurals, gerunds, etc.) to avoid false positives.

Suggested skills are pre-selected (`[*]`). Use arrow keys and space to toggle any skill before confirming.

Once configured, every `skill-tags` sync automatically regenerates the category files from the saved config at `~/.cursor/skill-tags-categories.conf`.

```bash
# Inject a focused category index instead of the full list:
@skills-frontend.md
@skills-testing.md
@skills-ai-agents.md
```

Predefined categories: `frontend`, `backend`, `database`, `testing`, `design`, `accessibility`, `performance`, `ai-agents`, `devops`, `marketing`, `mobile`, `documentation`. You can also create custom categories with any name.

---

## Agent Setup Prompt

Copy and paste this into your Cursor agent to autoconfigure skill-tags:

<details>
<summary>Click to expand the full setup prompt</summary>

```text
Install and configure the `skill-tags` package (npm: https://www.npmjs.com/package/skill-tags, github: https://github.com/steve-piece/skill-tags) for me.

Use a terminal that runs outside the sandbox with full permissions to avoid permission errors during install. In Cursor, this means using a non-sandboxed terminal session if available (required_permissions: ["all"] if running via agent shell tools).

Steps to perform:
1. Install the package: `npm install skill-tags -g`
2. Run `skill-tags --setup` — when prompted, choose Global and Auto (recommended)
3. Source my shell rc file or instruct me to do so manually
4. Run `skill-tags` to perform an initial sync of all installed skills

When complete, output a summary that includes:
- Where the command file was generated (~/.cursor/commands/skill-tags.md)
- How to use it: typing @skill-tags.md in any Cursor chat attaches the full index of skills for the agent to assess
- How the auto-trigger works: `skills add/remove <pkg>` now automatically syncs after every install/removal
- How to manually re-sync at any time: run `skill-tags`
- The total number of skills that were indexed
- (Optional) To create category-specific indexes for more focused context, run `skill-tags --categories`
```

</details>

---

## Install Options

### Global install (npm)

```bash
npm install skill-tags -g
skill-tags --setup   # choose: Global
source ~/.zshrc
```

### Project install (npm)

```bash
npm install skill-tags --save-dev
npx skill-tags --setup   # choose: Project
```

Adds `"skills": "st-skills"` to `package.json`. Use `npm run skills add <pkg>` to add project skills — auto-syncs `.cursor/commands/project-skill-tags.md` on every change.

### One-off run (no install)

```bash
npx skill-tags
```

### Install via curl

```bash
curl -fsSL https://raw.githubusercontent.com/steve-piece/skill-tags/main/install.sh | bash
```

Then reload your shell:

```bash
source ~/.zshrc   # or ~/.bash_profile / ~/.bashrc
```

## How It Works

After global setup, the `skills` command wraps `npx skills` and automatically runs a sync after every `skills add` or `skills remove`:

```bash
# Install (or remove) a skill — sync runs automatically
skills add vercel-labs/agent-skills/vercel-react-best-practices

# The command file is updated:
# ~/.cursor/commands/skill-tags.md

# Use it in Cursor chat:
# @skill-tags.md
```

## Project-Level Install

Install skill-tags as a dev dependency to manage project-specific skills without touching your global shell config. The `--setup` wizard adds a `"skills"` npm script backed by the bundled `st-skills` binary.

```bash
npm install skill-tags --save-dev
npx skill-tags --setup   # choose: Project
```

After setup, `package.json` will include:

```json
"scripts": {
  "skills": "st-skills"
}
```

Use `npm run skills` to add, remove, or update project skills:

```bash
npm run skills add owner/repo/skill-name     # adds skill + auto-syncs
npm run skills remove owner/repo/skill-name  # removes skill + auto-syncs
npm run skills update owner/repo/skill-name  # updates skill + auto-syncs

# Manual re-sync:
skill-tags --local

# Use in Cursor chat:
# @project-skill-tags.md
```

The `st-skills` binary (from this package) wraps `npx skills`, then automatically runs `skill-tags --local` on every successful `add`, `remove`, or `update`, writing the index to `.cursor/commands/project-skill-tags.md`.

## CLI Reference

```bash
skill-tags                # sync all skills, generate/update the command file
skill-tags --categories   # open interactive category wizard (CRUD)
skill-tags --setup        # interactive setup: choose Global (shell profile) or Project (package.json)
skill-tags --global       # skip local skills (.agents/skills in CWD); scan global sources only
skill-tags --local        # scan only .agents/skills in CWD; write to .cursor/commands/project-skill-tags.md
skill-tags --version      # print version
skill-tags --help         # show usage
```

### `st-skills` (project binary)

```bash
npm run skills add <pkg>     # install a project skill + auto-sync
npm run skills remove <pkg>  # remove a project skill + auto-sync
npm run skills update <pkg>  # update a project skill + auto-sync
```

`st-skills` is registered in `package.json` by `skill-tags --setup` (local mode). It wraps `npx skills` and calls `skill-tags --local` after every mutating command.

## Manual Sync

Run at any time to regenerate the command file:

```bash
skill-tags

# Or via bash directly:
bash ~/.cursor/sync-skill-commands.sh
```

## Skill Sources Scanned

Skills are discovered from all of these locations automatically. When the same skill name appears in multiple sources, the first match wins (priority order):

| Priority | Directory | Source |
|---|---|---|
| 1 | `~/.agents/skills/` | `npx skills add` installs |
| 2 | `~/.cursor/skills-cursor/` | Cursor built-in skills |
| 3 | `~/.cursor/plugins/cache/` | Cursor Marketplace plugins |
| 4 | `~/.claude/plugins/cache/` | Claude plugins |
| 5 | `~/.codex/skills/` | Codex skills |
| 6 | `./.agents/skills/` | Project-level skills (CWD) |

## Generated File Format

The `~/.cursor/commands/skill-tags.md` (global) and `./.cursor/commands/project-skill-tags.md` (local) contain:

- An opening instruction for the agent to assess all skills and apply them autonomously.
- Instructions for the agent on how to plan with skills when in Plan Mode.
- A full list of available skills, including their titles, directory paths, and descriptions.

This gives the agent a complete map of your skill library when you reference it with `@`.

## How Categorization Works

The `--categories` wizard reads the generated `skill-tags.md` file as its keyword search source. Each skill's title, path, and description are lowercased and matched against category-specific keywords (tool names, framework names, and domain acronyms only — no generic English words).

Matching uses strict full-word boundaries with automatic suffix expansion, so `brainstorm` matches "brainstorming" and `deploy` matches "deployment" — without false positives from partial substring matches.

Keywords are intentionally specific (e.g., `vitest`, `playwright`, `supabase`, `tailwind`) rather than generic (e.g., ~~test~~, ~~server~~, ~~component~~) to keep auto-suggestions accurate.

---

## Uninstall

```bash
# Via npm
npm uninstall -g skill-tags

# Clean up generated command file and shell wrapper
bash uninstall.sh
```

## Requirements

- macOS or Linux (Windows not supported — requires bash)
- Node.js >=18
- bash or zsh
- [Cursor IDE](https://cursor.com)

## License

MIT