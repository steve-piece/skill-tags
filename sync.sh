#!/usr/bin/env bash
# sync.sh
# Generates ~/.cursor/commands/skill-tags.md listing all installed skills.
# Scans every known skill location, deduplicates by name (first-found wins).
# Works on macOS and Linux. bash 3.2 compatible (macOS default).
# Called by bin/skill-tags.js — flag handling (--help, --setup, etc.) lives there.

set -euo pipefail

VERSION="1.2.0"

GLOBAL_COMMANDS_DIR="${HOME}/.cursor/commands"
OUTPUT_FILE="${GLOBAL_COMMANDS_DIR}/skill-tags.md"
CATEGORIES_CONFIG="${HOME}/.cursor/skill-tags-categories.conf"

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

# ─── Temp files (created early; trap cleans up on any exit) ────────────────────

SKILLS_TEMP="$(mktemp)"
SKILLS_META_DIR="$(mktemp -d)"
trap 'rm -f "$SKILLS_TEMP"; rm -rf "$SKILLS_META_DIR"' EXIT

# ─── Flags ─────────────────────────────────────────────────────────────────────

GLOBAL_ONLY=false

for arg in "$@"; do
  case "$arg" in
    --global-only) GLOBAL_ONLY=true ;;
  esac
done

# ─── Helpers ───────────────────────────────────────────────────────────────────

count_found=0
count_dupes=0

log()     { printf "  %s\n" "$*"; }
success() { printf "  ✓ %s\n" "$*"; }

# Tracks which skill names have already been processed (deduplication).
# Uses a delimited string for bash 3.2 compatibility (no associative arrays).
seen_skills=":"

# Convert kebab-case or snake_case to Title Case
to_title_case() {
  echo "$1" | sed 's/[-_]/ /g' | awk '{for(i=1;i<=NF;i++) $i=toupper(substr($i,1,1)) substr($i,2)}1'
}

# Extract description: from YAML frontmatter, or fall back to first content line
extract_description() {
  local skill_file="$1"
  local desc

  desc=$(awk '
    BEGIN { in_fm=0 }
    /^---/ {
      if (in_fm == 0) { in_fm=1; next }
      else { exit }
    }
    in_fm==1 && /^description:/ {
      sub(/^description:[[:space:]]*/, "")
      gsub(/^["'"'"']|["'"'"']$/, "")
      print
      exit
    }
  ' "$skill_file" 2>/dev/null)

  if [[ -n "$desc" ]]; then
    echo "$desc"
    return
  fi

  desc=$(awk '
    BEGIN { in_fm=0 }
    /^---/ {
      if (in_fm == 0) { in_fm=1; next }
      else { in_fm=0; next }
    }
    in_fm { next }
    /^#/ { next }
    /^[[:space:]]*$/ { next }
    { print; exit }
  ' "$skill_file" 2>/dev/null)

  echo "${desc:-(No description available)}"
}

# Extract metadata.tags from YAML frontmatter.
# Returns a colon-delimited string, e.g. "frontend:react:animation"
extract_metadata_tags() {
  local skill_file="$1"
  awk '
    BEGIN { in_fm=0; in_meta=0 }
    /^---/ { if (in_fm==0) { in_fm=1; next } else { exit } }
    in_fm && /^metadata:/ { in_meta=1; next }
    in_meta && /^[^ ]/ { in_meta=0 }
    in_meta && /tags:/ {
      gsub(/.*tags:[[:space:]]*/, "")
      gsub(/[\[\]]/, "")
      gsub(/,/, ":")
      gsub(/[[:space:]]/, "")
      print
      exit
    }
  ' "$skill_file" 2>/dev/null
}

collect_skill() {
  local skill_dir="$1"
  local skill_name="$2"
  local skill_file="${skill_dir}/SKILL.md"
  local display_path="${skill_dir/#$HOME/~}"
  local title
  title="$(to_title_case "$skill_name")"
  local desc
  desc="$(extract_description "$skill_file")"
  local tags
  tags="$(extract_metadata_tags "$skill_file")"

  # Markdown section for skill-tags.md
  cat >> "$SKILLS_TEMP" <<EOF

### ${title}
\`${display_path}\`

${desc}
EOF

  # Pipe-delimited metadata record for categorization lookups
  # Format: display_path|description|tags
  printf '%s|%s|%s\n' "$display_path" "$desc" "$tags" > "${SKILLS_META_DIR}/${skill_name}"

  count_found=$(( count_found + 1 ))
  log "  Found: ${title} (${display_path})"
}

# Recursively find all SKILL.md files under a directory tree.
# Handles flat dirs (~/.agents/skills/name/SKILL.md) and
# nested plugin caches (cache/plugin/version/skills/name/SKILL.md).
scan_tree() {
  local base_dir="$1"

  [[ -d "$base_dir" ]] || return 0

  local found=0
  local base_dir_slash="${base_dir}/"

  while IFS= read -r skill_file; do
    # Check only the relative portion of the path for hidden components.
    # The base_dir itself may live inside hidden dirs (e.g. ~/.agents/) so we
    # must not apply the dot-filter to the full absolute path.
    local rel="${skill_file#$base_dir_slash}"
    if echo "$rel" | grep -q '/\.'; then
      continue
    fi

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
    collect_skill "$skill_dir" "$skill_name"
    found=$(( found + 1 ))
  done < <(find "$base_dir" -name "SKILL.md" 2>/dev/null | sort)

  if [[ $found -gt 0 ]]; then
    log "  Found $found skill(s) in ${base_dir/#$HOME/~}"
  fi
}

# ─── Generate category files ────────────────────────────────────────────────────

# Reads ~/.cursor/skill-tags-categories.conf and writes a skills-<category>.md
# command file for each category. Called automatically on every sync when config exists.
generate_category_files() {
  [[ -f "$CATEGORIES_CONFIG" ]] || return 0

  local gen_count=0

  while IFS='=' read -r cat_name skill_list; do
    [[ "$cat_name" == "#"* || -z "$cat_name" ]] && continue
    [[ -z "$skill_list" ]] && continue

    local title
    title="$(to_title_case "$cat_name")"
    local out="${GLOBAL_COMMANDS_DIR}/skills-${cat_name}.md"

    local skills_section=""
    while IFS= read -r sname; do
      [[ -z "$sname" ]] && continue
      local meta_file="${SKILLS_META_DIR}/${sname}"
      if [[ -f "$meta_file" ]]; then
        local display_path desc stitle
        display_path="$(awk -F'|' '{print $1}' "$meta_file")"
        desc="$(awk -F'|' '{print $2}' "$meta_file")"
        stitle="$(to_title_case "$sname")"
        skills_section="${skills_section}
### ${stitle}
\`${display_path}\`

${desc}
"
      fi
    done < <(echo "$skill_list" | tr ',' '\n')

    cat > "$out" <<EOF
# Skills: ${title}

<!-- Auto-generated by sync.sh (skill-tags) v${VERSION} — do not edit manually -->

Assess the following ${title} skills available in this workspace and apply any that are relevant to completing the user's request at the highest level of efficiency, quality, and completeness. When skills overlap in scope, assess the overlapping skills in greater detail and autonomously determine which is the best match for the project or the specific request — do not prompt the user to resolve overlaps.

CRITICAL REQUIREMENT: Before applying any skill, you MUST use the Read tool to read the full contents of the skill file at the provided path. Do not assume the skill's behavior from its title or description alone.

If operating in Plan Mode, explicitly include references to specific skills to use and (if applicable) subagents to utilize for efficient programming within the contents of the plan and the plan's TODOs.

Examples:
- "Use the \`responsive-design/SKILL.md\` to apply advanced clamp-based responsiveness to the new navigation bar."
- "Delegate to the \`frontend-designer\` subagent using \`ui-ux-pro-max/SKILL.md\` to build the polished component."
- "Utilize \`supabase-postgres-best-practices/SKILL.md\` when designing the database schema for the user profiles."

## ${title} Skills
${skills_section}
EOF

    gen_count=$(( gen_count + 1 ))
    success "Generated: ${out/#$HOME/~}"
  done < "$CATEGORIES_CONFIG"

  if [[ $gen_count -gt 0 ]]; then
    printf "  Category files: %d generated\n" "$gen_count"
  fi
}

# ─── Main ──────────────────────────────────────────────────────────────────────

printf "\n  skill-tags v%s — syncing skills\n\n" "$VERSION"

# 1. Scan all global/user-level skill sources
for entry in "${GLOBAL_SKILL_SOURCES[@]}"; do
  dir="${entry%%:*}"
  label="${entry##*:}"
  if [[ -d "$dir" ]]; then
    log "Scanning ${label}: ${dir/#$HOME/~}"
    scan_tree "$dir"
  fi
done

# 2. Project-level skills (.agents/skills in CWD)
if [[ "$GLOBAL_ONLY" == "false" && -d ".agents/skills" ]]; then
  log "Scanning project skills: $(pwd)/.agents/skills"
  scan_tree "$(pwd)/.agents/skills"
fi

# ─── Write skill-tags.md ───────────────────────────────────────────────────────

mkdir -p "$GLOBAL_COMMANDS_DIR"

OPENING="Assess the following skills available in this workspace and apply any that are relevant to completing the user's request at the highest level of efficiency, quality, and completeness. When skills overlap in scope, assess the overlapping skills in greater detail and autonomously determine which is the best match for the project or the specific request — do not prompt the user to resolve overlaps.

CRITICAL REQUIREMENT: Before applying any skill, you MUST use the Read tool to read the full contents of the skill file at the provided path. Do not assume the skill's behavior from its title or description alone.

If operating in Plan Mode, explicitly include references to specific skills to use and (if applicable) subagents to utilize for efficient programming within the contents of the plan and the plan's TODOs.

Examples:
- \"Use the \`responsive-design/SKILL.md\` to apply advanced clamp-based responsiveness to the new navigation bar.\"
- \"Delegate to the \`frontend-designer\` subagent using \`ui-ux-pro-max/SKILL.md\` to build the polished component.\"
- \"Utilize \`supabase-postgres-best-practices/SKILL.md\` when designing the database schema for the user profiles.\""

is_update=false
[[ -f "$OUTPUT_FILE" ]] && is_update=true

cat > "$OUTPUT_FILE" <<EOF
# Skill Tags Command

<!-- Auto-generated by sync.sh (skill-tags) v${VERSION} — do not edit manually -->

${OPENING}

## Available Skills
$(cat "$SKILLS_TEMP")
EOF

# ─── Generate category files (if config exists) ────────────────────────────────

generate_category_files

# ─── Summary ───────────────────────────────────────────────────────────────────

printf "\n"
if [[ "$is_update" == "true" ]]; then
  printf "  ✓ Updated:   %s\n" "${OUTPUT_FILE/#$HOME/~}"
else
  printf "  ✓ Generated: %s\n" "${OUTPUT_FILE/#$HOME/~}"
fi
printf "  Skills:      %d indexed\n" "$count_found"
if [[ $count_dupes -gt 0 ]]; then
  printf "  Duplicates:  %d skipped (covered by higher-priority source)\n" "$count_dupes"
fi
printf "\n  Tip: type @skill-tags.md in Cursor chat to load the full skills reference.\n\n"
