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
- [Changelog](#changelog)
- [License](#license)

---

## Quick Start

1. **Install:** `npm install skill-tags -g` (or `--save-dev` for project-level)
2. **Follow the prompts** — choose **Global** or **Project**, then **Auto** or **Manual** sync
3. **Use:** Reference `@skill-tags.md` in any Cursor chat

```bash
npm install skill-tags -g
# Setup wizard runs automatically — choose Global + Auto (recommended)
source ~/.zshrc
```

For project-level installs:

```bash
npm install skill-tags --save-dev
# Setup wizard runs automatically — choose Project + Auto
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

This opens an interactive wizard where you can add and remove categories. On save, skill assignment is powered by keyword matching against the generated `skill-tags.md` index — all text is lowercased with strict full-word matching and automatic suffix expansion (plurals, gerunds, etc.) to avoid false positives.

Once configured, every `skill-tags` sync automatically regenerates the category files from the saved config at `~/.cursor/skill-tags-categories.conf`.

For project-level categories (using only skills in `.agents/skills/`):

```bash
skill-tags --categories --local
```

Then reference focused category indexes instead of the full list:

```bash
@skills-frontend.md
@skills-testing.md
@skills-ai-agents.md
```

Predefined categories: `frontend`, `backend`, `database`, `testing`, `design`, `accessibility`, `performance`, `ai-agents`, `devops`, `marketing`, `mobile`, `documentation`.

---

## Agent Setup Prompt

Copy and paste this into your Cursor agent to autoconfigure skill-tags:

<details>
<summary>Click to expand the full setup prompt</summary>

```text
Install and configure the `skill-tags` package (npm: https://www.npmjs.com/package/skill-tags, github: https://github.com/steve-piece/skill-tags) for me.

Use a terminal that runs outside the sandbox with full permissions to avoid permission errors during install. In Cursor, this means using a non-sandboxed terminal session if available (required_permissions: ["all"] if running via agent shell tools).

Steps to perform:
1. Install the package: `npm install skill-tags -g` — the setup wizard runs automatically during install; when prompted, choose Global and Auto (recommended)
2. Source my shell rc file or instruct me to do so manually

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
npm install skill-tags -g     # setup wizard runs automatically
source ~/.zshrc
```

### Project install (npm)

```bash
npm install skill-tags --save-dev    # setup wizard runs automatically
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

Install skill-tags as a dev dependency to manage project-specific skills without touching your global shell config. The setup wizard runs automatically during install and adds a `"skills"` npm script backed by the bundled `st-skills` binary.

```bash
npm install skill-tags --save-dev
# choose: Project + Auto when prompted
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
skill-tags                       # sync all skills, generate/update the command file
skill-tags --categories          # open interactive category wizard
skill-tags --categories --local  # category wizard for project-level skills only
skill-tags --setup               # re-run setup wizard (runs automatically on first install)
skill-tags --global              # skip local skills (.agents/skills in CWD); scan global sources only
skill-tags --local               # scan only .agents/skills in CWD; write to .cursor/commands/project-skill-tags.md
skill-tags --latest              # update skill-tags to the latest version
skill-tags --version             # print version
skill-tags --help                # show usage
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

## Changelog

### v1.5.0

- **`--latest` flag** — run `skill-tags --latest` to check npm for updates and self-update in place
- **Project-level categories** — `skill-tags --categories --local` runs the category wizard using only project skills (`.agents/skills/`), stores config in `.cursor/skill-tags-categories.conf`, and generates category files in `.cursor/commands/`
- **Simplified category wizard** — streamlined to three actions: Add categories (multi-select from predefined list), Edit categories (multi-select to remove), and Save changes (runs keyword matching on save)
- **Quieter sync from wizard** — `sync.sh` accepts `--quiet` to suppress verbose scan output; the category wizard uses it for cleaner post-save output with an aligned summary table
- **Removed custom category input** — categories are now limited to the predefined list for consistency

### v1.4.0

- Interactive `--categories` wizard with keyword-based auto-assignment
- Category config persistence at `~/.cursor/skill-tags-categories.conf`
- Auto-regeneration of category files on every sync
- Predefined categories: frontend, backend, database, testing, design, accessibility, performance, ai-agents, devops, marketing, mobile, documentation

### v1.3.0

- `--local` flag for project-level skill scanning
- `st-skills` binary for project-level add/remove/update with auto-sync
- Project setup mode in `--setup` wizard

### v1.2.0

- `--global` flag to skip local skills
- `--setup` wizard with Global and Project modes
- Shell wrapper auto-sync on `skills add/remove`

### v1.1.0

- Deduplication across skill sources (first-found wins by priority)
- Support for nested plugin cache directories
- Description extraction from YAML frontmatter and first content line

### v1.0.0

- Initial release
- Scans all known skill locations and generates `~/.cursor/commands/skill-tags.md`
- Priority-ordered skill sources with deduplication

## License

MIT