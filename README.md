# skill-command-sync

Generate Cursor command files from installed [skills.sh](https://skills.sh) skills, enabling `@skill-name.md` references in chat for reliable, deterministic skill context injection.

## The Problem

Cursor's Agent Skills feature (currently in beta) only loads skill frontmatter into the agent's context window. The agent then decides whether to read the full `SKILL.md` based on that frontmatter alone — meaning skills are frequently ignored or inconsistently applied. There is also no visibility into whether a skill was triggered at all.

## The Solution

This tool generates a `.md` command file for each installed skill and places it in `~/.cursor/commands/`. You can then type `@skill-name.md` in any Cursor chat to explicitly attach the full skill content as context — bypassing the auto-discovery problem entirely.

## Quick Install

```bash
curl -fsSL https://raw.githubusercontent.com/stevenlight/skill-command-sync/main/install.sh | bash
```

Then reload your shell:

```bash
source ~/.zshrc   # or ~/.bash_profile / ~/.bashrc
```

## How It Works

After installation, the `skills` command in your terminal wraps `npx skills` and automatically runs a sync after every `skills add`:

```bash
# Install a skill and auto-sync
skills add vercel-labs/agent-skills/vercel-react-best-practices

# A new command file is generated:
# ~/.cursor/commands/vercel-react-best-practices.md

# Use it in Cursor chat:
# @vercel-react-best-practices.md
```

## Manual Sync

Run at any time to regenerate all command files:

```bash
bash ~/.cursor/sync-skill-commands.sh
```

## Skill Directories Scanned

| Directory | Output |
|---|---|
| `~/.agents/skills/` | `~/.cursor/commands/` |
| `~/.cursor/skills-cursor/` | `~/.cursor/commands/` |
| `./.agents/skills/` (project) | `./.cursor/commands/` |

## Generated File Format

Each `~/.cursor/commands/<skill-name>.md` contains:

- Skill location and file listing
- Full contents of `SKILL.md`

This gives the agent complete context about the skill when you reference it with `@`.

## Uninstall

```bash
bash uninstall.sh
```

Or manually:

1. Delete `~/.cursor/sync-skill-commands.sh`
2. Remove the `# ─── Cursor Skill Command Sync` block from `~/.zshrc`

## Requirements

- macOS or Linux
- bash or zsh
- `curl` or `wget` (for remote install)
- [Cursor IDE](https://cursor.com)
- [skills.sh](https://skills.sh) (`npx skills`)

## License

MIT
