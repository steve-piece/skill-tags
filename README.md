# skill-tags

Generate Cursor command files from installed [skills.sh](https://skills.sh) skills, enabling `@skill-name.md` references in chat for reliable, deterministic skill context injection.

## The Problem

Cursor's Agent Skills feature (currently in beta) only loads skill frontmatter into the agent's context window. The agent then decides whether to read the full `SKILL.md` based on that frontmatter alone — meaning skills are frequently ignored or inconsistently applied. There is also no visibility into whether a skill was triggered at all ([forum discussion](https://forum.cursor.com/t/agent-ignores-skill/149017)).

## The Solution

This tool generates a `.md` command file for each installed skill and places it in `~/.cursor/commands/`. You can then type `@skill-name.md` in any Cursor chat to explicitly attach the full skill content as context — bypassing the auto-discovery problem entirely.

## Install via npm

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

## Install via curl

```bash
curl -fsSL https://raw.githubusercontent.com/stevenlight/skill-command-sync/main/install.sh | bash
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
