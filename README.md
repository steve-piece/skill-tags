# skill-tags

Generates a single consolidated command file (`@skill-tags.md`) indexing all installed Cursor skills. Reference it in any chat to give the agent a complete directory of your available skills, enabling it to autonomously select and apply the right tools for the task.

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
- [Skill Metadata Tags](#skill-metadata-tags)
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

This opens a CRUD wizard where you can create, edit, and delete categories. Skill assignment is powered by a two-tier auto-suggestion system:

1. **`metadata.tags` (high confidence)** — if a skill's `SKILL.md` includes a `metadata.tags` frontmatter field, those tags are matched directly against the category.
2. **Keyword fallback** — for skills without `metadata.tags`, the skill name and description are scanned against a built-in keyword map.

Suggested skills are pre-selected (`[*]`). You can toggle any skill in or out by number before confirming.

Once configured, every `skill-tags` sync automatically regenerates the category files from the saved config at `~/.cursor/skill-tags-categories.conf`.

```bash
# Inject a focused category index instead of the full list:
@skills-frontend.md
@skills-testing.md
@skills-ai-agents.md
```

Predefined categories: `frontend`, `backend`, `database`, `testing`, `accessibility`, `performance`, `ai-agents`, `devops`, `design`. You can also create custom categories with any name.

---

## Agent Setup Prompt

Copy and paste this into your Cursor agent to autoconfigure skill-tags:

<details>
<summary>Click to expand the full setup prompt</summary>

```text
Install and configure the skill-tags package for me.

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

## Skill Metadata Tags

skill-tags uses the official `metadata` frontmatter field from the [skills.sh](https://skills.sh) spec to improve auto-categorization. If you are authoring a skill, add `metadata.tags` to improve how it is categorized:

```yaml
---
name: my-skill
description: Does X, Y, Z.
metadata:
  tags: [frontend, react, animation]
---
```

Skills with `metadata.tags` are surfaced as high-confidence matches in the `--categories` wizard and marked `[*]` with the tag source shown inline. Skills without tags fall back to keyword matching.

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
- Node.js >=14 (for npm install)
- bash or zsh
- [Cursor IDE](https://cursor.com)

## License

MIT