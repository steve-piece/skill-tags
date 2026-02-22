#!/usr/bin/env bash
# sync.sh
# Generates Cursor command files from ALL installed skills for @skill-name.md chat references.
# Scans every known skill location and deduplicates by name (first-found wins).
# Works on macOS and Linux. No external dependencies required.
#
# Usage:
#   bash sync.sh                    # sync all skills
#   bash sync.sh --global-only      # skip project-level skills
#   bash sync.sh --setup            # install shell wrapper (skills() auto-trigger)
#   bash sync.sh --version          # print version
#   bash sync.sh --help             # show usage

set -euo pipefail

VERSION="1.1.0"

GLOBAL_COMMANDS_DIR="${HOME}/.cursor/commands"
WRAPPER_MARKER="# ─── skill-tags / Cursor Skill Command Sync"

# ─── Priority-ordered skill source directories ─────────────────────────────────
# Earlier entries take priority when the same skill name exists in multiple locations.
# Format: "path:label"
GLOBAL_SKILL_SOURCES=(
  "${HOME}/.agents/skills:global skills"
  "${HOME}/.cursor/skills-cursor:cursor built-in skills"
  "${HOME}/.cursor/plugins/cache:cursor plugin cache"
  "${HOME}/.claude/plugins/cache:claude plugin cache"
  "${HOME}/.codex/skills:codex skills"
)

# ─── Shell setup helper ────────────────────────────────────────────────────────

detect_rc() {
  local shell_name
  shell_name="$(basename "${SHELL:-bash}")"
  if [[ "$shell_name" == "zsh" ]]; then
    echo "${HOME}/.zshrc"
  elif [[ "$(uname)" == "Darwin" ]]; then
    echo "${HOME}/.bash_profile"
  else
    echo "${HOME}/.bashrc"
  fi
}

cmd_setup() {
  local rc_file
  rc_file="$(detect_rc)"

  printf "\n  skill-tags: shell setup\n\n"

  if grep -q "$WRAPPER_MARKER" "$rc_file" 2>/dev/null; then
    printf "  Shell wrapper already installed in %s\n\n" "${rc_file/#$HOME/~}"
    return 0
  fi

  # Detect the sync script path (prefer the installed version, fall back to this script)
  local sync_path="${HOME}/.cursor/sync-skill-commands.sh"
  if [[ ! -f "$sync_path" ]]; then
    sync_path="$(cd "$(dirname "$0")" && pwd)/sync.sh"
  fi

  touch "$rc_file"
  cat >> "$rc_file" <<WRAPPER

${WRAPPER_MARKER} ────────────────────────────────────────────────
# Wraps \`npx skills\` to auto-generate @skill-name.md command files after install.
# Run manually: skill-tags   (or: bash ${sync_path})
function skills() {
  npx skills "\$@"
  local exit_code=\$?
  if [[ "\$1" == "add" && \$exit_code -eq 0 ]]; then
    bash "${sync_path}"
  fi
  return \$exit_code
}
# ─────────────────────────────────────────────────────────────────────────────
WRAPPER

  printf "  Added skills() wrapper to %s\n" "${rc_file/#$HOME/~}"
  printf "  Reload with: source %s\n\n" "${rc_file/#$HOME/~}"
}

# ─── Flags ─────────────────────────────────────────────────────────────────────

GLOBAL_ONLY=false

for arg in "$@"; do
  case "$arg" in
    --global-only) GLOBAL_ONLY=true ;;
    --version|-v)
      echo "skill-tags v${VERSION}"
      exit 0
      ;;
    --setup)
      cmd_setup
      exit 0
      ;;
    --help|-h)
      echo "skill-tags v${VERSION} — Cursor Skill Command Sync"
      echo ""
      echo "Usage: skill-tags [options]"
      echo ""
      echo "Options:"
      echo "  (none)           Scan all skill sources and generate/update command files"
      echo "  --global-only    Skip project-level skills (.agents/skills in CWD)"
      echo "  --setup          Install the skills() shell wrapper in ~/.zshrc (auto-trigger)"
      echo "  --version, -v    Print version"
      echo "  --help, -h       Show this help"
      echo ""
      echo "Skill sources scanned (priority order — first match wins):"
      echo "  ~/.agents/skills/              (skills installed via npx skills add)"
      echo "  ~/.cursor/skills-cursor/       (Cursor built-in skills)"
      echo "  ~/.cursor/plugins/cache/       (Cursor Marketplace plugin skills)"
      echo "  ~/.claude/plugins/cache/       (Claude plugin skills)"
      echo "  ~/.codex/skills/               (Codex skills)"
      echo "  ./.agents/skills/              (project-level skills, current directory)"
      echo ""
      echo "Output:"
      echo "  ~/.cursor/commands/<skill-name>.md   (global + plugin skills)"
      echo "  ./.cursor/commands/<skill-name>.md   (project-level skills)"
      exit 0
      ;;
  esac
done

# ─── Helpers ───────────────────────────────────────────────────────────────────

count_generated=0
count_updated=0
count_skipped=0
count_dupes=0

log()     { printf "  %s\n" "$*"; }
success() { printf "  ✓ %s\n" "$*"; }
updated() { printf "  ↺ %s\n" "$*"; }

# Tracks which skill names have already been processed (deduplication)
# Uses a delimited string for bash 3.2 compatibility (macOS default shell)
seen_skills=":"

generate_command() {
  local skill_dir="$1"
  local commands_dir="$2"
  local skill_name="$3"
  local skill_file="${skill_dir}/SKILL.md"

  local file_list
  file_list="$(ls "$skill_dir" 2>/dev/null)"

  local display_path="${skill_dir/#$HOME/~}"

  mkdir -p "$commands_dir"

  local output_file="${commands_dir}/${skill_name}.md"
  local is_update=false
  [[ -f "$output_file" ]] && is_update=true

  cat > "$output_file" <<EOF
# ${skill_name}

<!-- Auto-generated by sync.sh (skill-tags) v${VERSION} — do not edit manually -->
<!-- Source: ${skill_file} -->

**Skill Location:** \`${display_path}/\`

## Files in This Skill

\`\`\`
${file_list}
\`\`\`

---

$(cat "$skill_file")
EOF

  if [[ "$is_update" == "true" ]]; then
    updated "Updated:   ${output_file/#$HOME/~}"
    count_updated=$(( count_updated + 1 ))
  else
    success "Generated: ${output_file/#$HOME/~}"
    count_generated=$(( count_generated + 1 ))
  fi
}

# Recursively find all SKILL.md files under a directory tree.
# Handles flat dirs (~/.agents/skills/name/SKILL.md) and
# nested plugin caches (cache/plugin/version/skills/name/SKILL.md).
scan_tree() {
  local base_dir="$1"
  local commands_dir="$2"

  [[ -d "$base_dir" ]] || return 0

  local found=0

  while IFS= read -r skill_file; do
    local skill_dir
    skill_dir="$(dirname "$skill_file")"
    local skill_name
    skill_name="$(basename "$skill_dir")"

    # Skip if this skill name was already processed from a higher-priority source
    if [[ "$seen_skills" == *":${skill_name}:"* ]]; then
      count_dupes=$(( count_dupes + 1 ))
      continue
    fi

    seen_skills="${seen_skills}${skill_name}:"
    generate_command "$skill_dir" "$commands_dir" "$skill_name"
    found=$(( found + 1 ))
  done < <(find "$base_dir" -name "SKILL.md" 2>/dev/null | grep -v '/\.' | sort)

  [[ $found -gt 0 ]] && log "  Found $found skill(s) in ${base_dir/#$HOME/~}"
}

# ─── Main ──────────────────────────────────────────────────────────────────────

printf "\n🔄 Cursor Skill Command Sync v%s\n\n" "$VERSION"

# 1. Scan all global/user-level skill sources
for entry in "${GLOBAL_SKILL_SOURCES[@]}"; do
  dir="${entry%%:*}"
  label="${entry##*:}"
  if [[ -d "$dir" ]]; then
    log "Scanning ${label}: ${dir/#$HOME/~}"
    scan_tree "$dir" "$GLOBAL_COMMANDS_DIR"
  fi
done

# 2. Project-level skills (.agents/skills in CWD)
if [[ "$GLOBAL_ONLY" == "false" && -d ".agents/skills" ]]; then
  project_commands_dir="$(pwd)/.cursor/commands"
  log "Scanning project skills: $(pwd)/.agents/skills"
  scan_tree "$(pwd)/.agents/skills" "$project_commands_dir"
fi

# ─── Summary ───────────────────────────────────────────────────────────────────

total=$(( count_generated + count_updated ))
printf "\n"
printf "  New:       %d command file(s)\n" "$count_generated"
printf "  Updated:   %d command file(s)\n" "$count_updated"
[[ $count_dupes -gt 0 ]]   && printf "  Dupes:     %d skill(s) skipped (covered by higher-priority source)\n" "$count_dupes"
[[ $count_skipped -gt 0 ]] && printf "  Skipped:   %d dir(s) without SKILL.md\n" "$count_skipped"
printf "\n  Total:     %d command file(s) in %s\n" "$total" "${GLOBAL_COMMANDS_DIR/#$HOME/~}"
printf "\n  Tip: type @<skill-name>.md in Cursor chat to attach full skill context.\n\n"
