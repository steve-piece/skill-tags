# skill-tags

Generate Cursor command files for skills installed with [skills.sh](https://skills.sh), making it easy to reference skills using `@skill-name.md` in Cursor chat.

> [!IMPORTANT]
> Cursor's Agent Skills feature (currently in beta) only loads skill frontmatter into the agent's context window. The agent then decides whether to read the full `SKILL.md` based on that frontmatter alone — meaning skills are frequently ignored or inconsistently applied. There's also no visibility into whether a skill was triggered at all ([forum discussion](https://forum.cursor.com/t/agent-ignores-skill/149017)).

skill-tags bypasses this by generating a command file per skill in `~/.cursor/commands/`, so you can explicitly attach the full skill content by typing `@skill-name.md`.

> [!TIP]
> Stay tuned for a more permanent solution to this problem: I'm developing an open source community called [Cursor Kits](https://cursorkits.com). Cursor Kits is something I started before Cursor launched their [Plugin Marketplace](https://cursor.com/marketplace). It's the same idea, but built for the community (vs integration providers).

If you're interested in contributing to Cursor Kits, please let me know!

---

## Table of Contents

- [Quick Start](#quick-start)
- [Usage](#usage)
- [Agent Setup Prompt](#agent-setup-prompt)
- [Install Options](#install-options)
- [How It Works](#how-it-works)
- [CLI Reference](#cli-reference)
- [Manual Sync](#manual-sync)
- [Skill Sources Scanned](#skill-sources-scanned)
- [Generated File Format](#generated-file-format)
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

# Initial sync (generate command files)
skill-tags
```

## Usage

In any Cursor chat, attach a skill's full context by referencing the generated command file:

- `@<skill-name>.md`

Example:

```text
@vercel-react-best-practices.md
```

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
- How many command files were generated and where they live (~/.cursor/commands/)
- How to use them: typing @<skill-name>.md in any Cursor chat attaches the full skill context
- How the auto-trigger works: `skills add <pkg>` now automatically syncs after every install
- How to manually re-sync at any time: run `skill-tags`
- A list of the command files that were created so I can see what skills are now referenceable
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

After setup, the `skills` command wraps `npx skills` and automatically runs a sync after every `skills add`:

```bash
# Install a skill — sync runs automatically
skills add vercel-labs/agent-skills/vercel-react-best-practices

# A new command file is generated:
# ~/.cursor/commands/vercel-react-best-practices.md

# Use it in Cursor chat:
# @vercel-react-best-practices.md
```

## CLI Reference

```bash
skill-tags              # sync all skills, generate/update command files
skill-tags --setup      # install skills() shell wrapper in ~/.zshrc
skill-tags --global-only  # skip project-level skills
skill-tags --version    # print version
skill-tags --help       # show usage
```

## Manual Sync

Run at any time to regenerate all command files:

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

Each `~/.cursor/commands/<skill-name>.md` contains:

- Skill location and file listing
- Full contents of `SKILL.md`

This gives the agent complete context about the skill when you reference it with `@`.

## Uninstall

```bash
# Via npm
npm uninstall -g skill-tags

# Clean up generated command files and shell wrapper
bash uninstall.sh
```

## Requirements

- macOS or Linux (Windows not supported — requires bash)
- Node.js >=14 (for npm install)
- bash or zsh
- [Cursor IDE](https://cursor.com)

## License

MIT
