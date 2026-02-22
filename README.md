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

```bash
# Install (global, recommended)
npm install -g skill-tags

# Add the shell auto-trigger wrapper
skill-tags --setup
source ~/.zshrc

# Initial sync (generate command file)
skill-tags
```

## Usage

In any Cursor chat, attach the full index of your skills by referencing the generated command file:

- `@skill-tags.md`

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

First, confirm with me: should this be a global install (adds `skill-tags` to PATH, recommended for most users) or a local project devDependency? Wait for my answer before proceeding.

Once confirmed, use a terminal that runs outside the sandbox with full permissions to avoid permission errors during install. In Cursor, this means using a non-sandboxed terminal session if available (required_permissions: ["all"] if running via agent shell tools).

Steps to perform:
1. Install the package based on my preference:
   - Global: `npm install -g skill-tags`
   - Local: `npm install --save-dev skill-tags`
2. Run `skill-tags --setup` to install the `skills()` shell wrapper in my rc file (~/.zshrc or ~/.bash_profile)
3. Run `skill-tags` to perform an initial sync of all installed skills
4. Source my shell rc file or instruct me to do so manually

When complete, output a summary that includes:
- Where the command file was generated (~/.cursor/commands/skill-tags.md)
- How to use it: typing @skill-tags.md in any Cursor chat attaches the full index of skills for the agent to assess
- How the auto-trigger works: `skills add/remove <pkg>` now automatically syncs after every install/removal
- How to manually re-sync at any time: run `skill-tags`
- The total number of skills that were indexed
```

</details>

---

## Install Options

### Install via npm

```bash
# Global install (recommended) — adds `skill-tags` to your PATH
npm install -g skill-tags

# One-off run without installing
npx skill-tags

# Project devDependency (adds to package.json)
npm install --save-dev skill-tags
```

After global install, set up the shell auto-trigger wrapper:

```bash
skill-tags --setup
source ~/.zshrc
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

After setup, the `skills` command wraps `npx skills` and automatically runs a sync after every `skills add` or `skills remove`:

```bash
# Install (or remove) a skill — sync runs automatically
skills add vercel-labs/agent-skills/vercel-react-best-practices

# The single command file is updated:
# ~/.cursor/commands/skill-tags.md

# Use it in Cursor chat:
# @skill-tags.md
```

## CLI Reference

```bash
skill-tags              # sync all skills, generate/update the command file
skill-tags --categories # open interactive category wizard (CRUD)
skill-tags --setup      # install skills() shell wrapper in ~/.zshrc
skill-tags --global-only  # skip project-level skills
skill-tags --version    # print version
skill-tags --help       # show usage
```

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

The `~/.cursor/commands/skill-tags.md` contains:

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