#!/usr/bin/env bash
# sync.sh
# Generates ~/.cursor/commands/skill-tags.md listing all installed skills.
# Optionally generates categorized skill files via --categories wizard.
# Scans every known skill location, deduplicates by name (first-found wins).
# Works on macOS and Linux. bash 3.2 compatible (macOS default).
#
# Usage:
#   bash sync.sh                    # generate skill-tags.md
#   bash sync.sh --categories       # interactive category wizard (CRUD)
#   bash sync.sh --global-only      # skip project-level skills
#   bash sync.sh --setup            # install shell wrapper (skills() auto-trigger)
#   bash sync.sh --version          # print version
#   bash sync.sh --help             # show usage

set -euo pipefail

VERSION="1.1.0"

GLOBAL_COMMANDS_DIR="${HOME}/.cursor/commands"
OUTPUT_FILE="${GLOBAL_COMMANDS_DIR}/skill-tags.md"
CATEGORIES_CONFIG="${HOME}/.cursor/skill-tags-categories.conf"
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

# ─── Temp files (created early; trap cleans up on any exit) ────────────────────

SKILLS_TEMP="$(mktemp)"
SKILLS_META_DIR="$(mktemp -d)"
trap 'rm -f "$SKILLS_TEMP"; rm -rf "$SKILLS_META_DIR"' EXIT

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

  local sync_path="${HOME}/.cursor/sync-skill-commands.sh"
  if [[ ! -f "$sync_path" ]]; then
    sync_path="$(cd "$(dirname "$0")" && pwd)/sync.sh"
  fi

  touch "$rc_file"
  cat >> "$rc_file" <<WRAPPER

${WRAPPER_MARKER} ────────────────────────────────────────────────
# Wraps \`npx skills\` to auto-generate skill-tags.md after install/removal.
# Run manually: skill-tags   (or: bash ${sync_path})
function skills() {
  npx skills "\$@"
  local exit_code=\$?
  if [[ "\$1" == "add" || "\$1" == "remove" ]] && [[ \$exit_code -eq 0 ]]; then
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
RUN_CATEGORIES=false

for arg in "$@"; do
  case "$arg" in
    --global-only)  GLOBAL_ONLY=true ;;
    --categories)   RUN_CATEGORIES=true ;;
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
      echo "  (none)           Scan all skill sources and generate skill-tags.md"
      echo "  --categories     Open interactive category wizard (create/edit/delete groups)"
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
      echo "  ~/.cursor/commands/skill-tags.md          (full index of all skills)"
      echo "  ~/.cursor/commands/skills-<category>.md   (generated by --categories)"
      echo ""
      echo "Category config:"
      echo "  ~/.cursor/skill-tags-categories.conf"
      exit 0
      ;;
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

# ─── Category helpers ───────────────────────────────────────────────────────────

PREDEFINED_CATEGORIES="frontend backend database testing accessibility performance ai-agents devops design"

# Hardcoded keyword map for Tier 2 fallback categorization.
# Returns a colon-delimited keyword string for the given category name.
get_category_keywords() {
  case "$1" in
    frontend)      echo "react:next:vue:svelte:css:html:responsive:component:ui:ux:tailwind:animation:design-system" ;;
    backend)       echo "api:server:node:express:rest:graphql:stripe:payment:webhook" ;;
    database)      echo "postgres:sql:supabase:database:schema:query:migration:orm" ;;
    testing)       echo "test:vitest:playwright:jest:coverage:mock:spec:e2e" ;;
    accessibility) echo "accessibility:aria:wcag:a11y:screen-reader:keyboard" ;;
    performance)   echo "performance:optimize:speed:lazy:cache:memoize:bundle:lighthouse" ;;
    ai-agents)     echo "agent:skill:claude:cursor:mcp:subagent:browser:automation:llm:ai:workflow" ;;
    devops)        echo "deploy:vercel:docker:ci:cd:build:pipeline:github:actions" ;;
    design)        echo "design:figma:ux:animation:motion:color:typography:shadow:gradient" ;;
    *)             echo "" ;;
  esac
}

# Two-tier categorization check for a single skill against a category.
# Tier 1: metadata.tags match (higher confidence)
# Tier 2: keyword match against skill name + description (fallback)
# Prints "1" for tier-1 match, "2" for tier-2 match, "" for no match.
# All interactive output must go to stderr; stdout is reserved for the return value.
skill_match_tier() {
  local skill_name="$1"
  local category="$2"
  local meta_file="${SKILLS_META_DIR}/${skill_name}"
  [[ -f "$meta_file" ]] || return 0

  local tags
  tags="$(awk -F'|' '{print $3}' "$meta_file")"
  local desc
  desc="$(awk -F'|' '{print $2}' "$meta_file")"
  local cat_keywords
  cat_keywords="$(get_category_keywords "$category")"

  # Tier 1 — metadata.tags
  if [[ -n "$tags" && -n "$cat_keywords" ]]; then
    local tag
    while IFS= read -r tag; do
      [[ -z "$tag" ]] && continue
      if echo ":${cat_keywords}:" | grep -qi ":${tag}:"; then
        echo "1"
        return
      fi
    done < <(echo "$tags" | tr ':' '\n')
  fi

  # Tier 2 — keyword match against name + description
  if [[ -n "$cat_keywords" ]]; then
    local search_text="${skill_name} ${desc}"
    local kw
    while IFS= read -r kw; do
      [[ -z "$kw" ]] && continue
      if echo "$search_text" | grep -qi "$kw"; then
        echo "2"
        return
      fi
    done < <(echo "$cat_keywords" | tr ':' '\n')
  fi
}

# Read current skill assignments for a category from the config file.
read_config_category() {
  local category="$1"
  if [[ ! -f "$CATEGORIES_CONFIG" ]]; then
    echo ""
    return
  fi
  grep "^${category}=" "$CATEGORIES_CONFIG" 2>/dev/null | sed "s/^${category}=//" || true
}

# Write (create or update) a category line in the config file.
write_config_category() {
  local category="$1"
  local skill_list="$2"
  local tmp
  tmp="$(mktemp)"

  if [[ -f "$CATEGORIES_CONFIG" ]] && grep -q "^${category}=" "$CATEGORIES_CONFIG" 2>/dev/null; then
    # Replace existing line
    awk -v cat="$category" -v list="$skill_list" \
      'substr($0,1,length(cat)+1)==cat"=" { print cat"="list; next } { print }' \
      "$CATEGORIES_CONFIG" > "$tmp"
  else
    # Append new line
    if [[ -f "$CATEGORIES_CONFIG" ]]; then
      cp "$CATEGORIES_CONFIG" "$tmp"
    else
      printf '# skill-tags category config — edit with: skill-tags --categories\n' > "$tmp"
    fi
    echo "${category}=${skill_list}" >> "$tmp"
  fi

  mv "$tmp" "$CATEGORIES_CONFIG"
}

# Remove a category from the config and delete its generated command file.
delete_config_category() {
  local category="$1"
  [[ -f "$CATEGORIES_CONFIG" ]] || return 0
  local tmp
  tmp="$(mktemp)"
  grep -v "^${category}=" "$CATEGORIES_CONFIG" > "$tmp" || true
  mv "$tmp" "$CATEGORIES_CONFIG"
  rm -f "${GLOBAL_COMMANDS_DIR}/skills-${category}.md"
}

# Interactive skill-selection UI for a category.
# All display output goes to stderr; echoes the final comma-delimited skill list to stdout.
select_skills_for_category() {
  local category="$1"
  local current_assignments="$2"

  local skill_names=()
  local skill_selected=()
  local skill_tiers=()

  # Build the full list of skills from SKILLS_META_DIR
  for meta_file in "${SKILLS_META_DIR}"/*; do
    [[ -f "$meta_file" ]] || continue
    local sname
    sname="$(basename "$meta_file")"
    skill_names+=("$sname")

    local tier
    tier="$(skill_match_tier "$sname" "$category")"
    skill_tiers+=("$tier")

    # Pre-select if already in current_assignments, or if there's a tier match and
    # this is a fresh category (no prior assignments).
    if echo ":${current_assignments}:" | grep -q ":${sname}:"; then
      skill_selected+=("1")
    elif [[ -n "$tier" && -z "$current_assignments" ]]; then
      skill_selected+=("1")
    else
      skill_selected+=("")
    fi
  done

  while true; do
    printf "\n  Category: %s\n" "$category" >&2
    printf "  Skills (toggle by number, Enter to confirm):\n\n" >&2

    local i=0
    while [[ $i -lt ${#skill_names[@]} ]]; do
      local sname="${skill_names[$i]}"
      local tier="${skill_tiers[$i]}"
      local sel="${skill_selected[$i]}"
      local num=$(( i + 1 ))

      local marker="[ ]"
      [[ "$sel" == "1" ]] && marker="[*]"

      local hint=""
      local tags
      tags="$(awk -F'|' '{print $3}' "${SKILLS_META_DIR}/${sname}" 2>/dev/null || true)"
      if [[ "$tier" == "1" && -n "$tags" ]]; then
        local readable_tags
        readable_tags="$(echo "$tags" | tr ':' ', ' | sed 's/, $//')"
        hint="  (metadata.tags: ${readable_tags})"
      elif [[ "$tier" == "2" ]]; then
        hint="  (keyword match)"
      fi

      printf "  %s %3d  %-45s%s\n" "$marker" "$num" "$sname" "$hint" >&2
      i=$(( i + 1 ))
    done

    printf "\n  Toggle by number (space-separated) or Enter to confirm: " >&2
    local input
    read -r input

    if [[ -z "$input" ]]; then
      break
    fi

    for num in $input; do
      if echo "$num" | grep -q '^[0-9][0-9]*$'; then
        local idx=$(( num - 1 ))
        if [[ $idx -ge 0 && $idx -lt ${#skill_names[@]} ]]; then
          if [[ "${skill_selected[$idx]}" == "1" ]]; then
            skill_selected[$idx]=""
          else
            skill_selected[$idx]="1"
          fi
        fi
      fi
    done
  done

  # Return the final comma-delimited list via stdout
  local result=""
  local i=0
  while [[ $i -lt ${#skill_names[@]} ]]; do
    if [[ "${skill_selected[$i]}" == "1" ]]; then
      [[ -n "$result" ]] && result="${result},"
      result="${result}${skill_names[$i]}"
    fi
    i=$(( i + 1 ))
  done

  echo "$result"
}

# ─── Category command ───────────────────────────────────────────────────────────

cmd_categories() {
  printf "\n  skill-tags: category wizard\n\n"
  printf "  Scanning all skills...\n"

  for entry in "${GLOBAL_SKILL_SOURCES[@]}"; do
    local dir="${entry%%:*}"
    [[ -d "$dir" ]] && scan_tree "$dir"
  done
  if [[ "$GLOBAL_ONLY" == "false" && -d ".agents/skills" ]]; then
    scan_tree "$(pwd)/.agents/skills"
  fi

  printf "  Found %d skill(s)\n" "$count_found"

  mkdir -p "$GLOBAL_COMMANDS_DIR"
  if [[ ! -f "$CATEGORIES_CONFIG" ]]; then
    printf '# skill-tags category config — edit with: skill-tags --categories\n' > "$CATEGORIES_CONFIG"
  fi

  # Main CRUD loop
  while true; do
    printf "\n  Current categories:\n"

    local cat_names=()
    local has_cats=false

    if [[ -f "$CATEGORIES_CONFIG" ]]; then
      while IFS='=' read -r cat_name skill_list; do
        [[ "$cat_name" == "#"* || -z "$cat_name" ]] && continue
        cat_names+=("$cat_name")
        local count
        count="$(echo "$skill_list" | awk -F',' '{print NF}')"
        [[ -z "$skill_list" ]] && count=0
        printf "    %d) %s (%s skills)\n" "${#cat_names[@]}" "$cat_name" "$count"
        has_cats=true
      done < "$CATEGORIES_CONFIG"
    fi

    if [[ "$has_cats" == "false" ]]; then
      printf "    (none yet)\n"
    fi

    printf "\n  [a] Add    [e] Edit    [d] Delete    [s] Save & generate    [q] Quit\n"
    printf "  > "
    local action
    read -r action

    case "$action" in
      a|A)
        # Show predefined category list
        printf "\n  Predefined categories:\n"
        local pcat_names=()
        local pcat
        for pcat in $PREDEFINED_CATEGORIES; do
          pcat_names+=("$pcat")
          printf "    %d) %s\n" "${#pcat_names[@]}" "$pcat"
        done
        printf "    c) custom\n"
        printf "  > "
        local choice
        read -r choice

        local new_cat=""
        if [[ "$choice" == "c" || "$choice" == "C" ]]; then
          printf "  Category name (lowercase, hyphens ok): "
          read -r new_cat
          new_cat="$(echo "$new_cat" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9-]/-/g' | sed 's/--*/-/g' | sed 's/^-//' | sed 's/-$//')"
        elif echo "$choice" | grep -q '^[0-9][0-9]*$'; then
          local pidx=$(( choice - 1 ))
          if [[ $pidx -ge 0 && $pidx -lt ${#pcat_names[@]} ]]; then
            new_cat="${pcat_names[$pidx]}"
          fi
        fi

        if [[ -n "$new_cat" ]]; then
          local current
          current="$(read_config_category "$new_cat")"
          local result
          result="$(select_skills_for_category "$new_cat" "$current")"
          write_config_category "$new_cat" "$result"
          printf "\n  ✓ Saved: %s\n" "$new_cat"
        fi
        ;;

      e|E)
        if [[ ${#cat_names[@]} -eq 0 ]]; then
          printf "  No categories yet. Use [a] to add one.\n"
          continue
        fi
        printf "  Edit which category? (number): "
        local edit_num
        read -r edit_num
        if echo "$edit_num" | grep -q '^[0-9][0-9]*$'; then
          local eidx=$(( edit_num - 1 ))
          if [[ $eidx -ge 0 && $eidx -lt ${#cat_names[@]} ]]; then
            local edit_cat="${cat_names[$eidx]}"
            local current
            current="$(read_config_category "$edit_cat")"
            local result
            result="$(select_skills_for_category "$edit_cat" "$current")"
            write_config_category "$edit_cat" "$result"
            printf "\n  ✓ Updated: %s\n" "$edit_cat"
          fi
        fi
        ;;

      d|D)
        if [[ ${#cat_names[@]} -eq 0 ]]; then
          printf "  No categories yet.\n"
          continue
        fi
        printf "  Delete which category? (number): "
        local del_num
        read -r del_num
        if echo "$del_num" | grep -q '^[0-9][0-9]*$'; then
          local didx=$(( del_num - 1 ))
          if [[ $didx -ge 0 && $didx -lt ${#cat_names[@]} ]]; then
            local del_cat="${cat_names[$didx]}"
            printf "  Delete '%s' and its generated file? [y/N] " "$del_cat"
            local confirm
            read -r confirm
            local confirm_lower
            confirm_lower="$(echo "$confirm" | tr '[:upper:]' '[:lower:]')"
            if [[ "$confirm_lower" == "y" ]]; then
              delete_config_category "$del_cat"
              printf "  ✓ Deleted: %s\n" "$del_cat"
            fi
          fi
        fi
        ;;

      s|S)
        printf "\n  Generating category files...\n"
        generate_category_files
        printf "\n  Done. Run 'skill-tags' to rebuild the full index.\n\n"
        exit 0
        ;;

      q|Q|"")
        printf "\n  Exiting without generating files.\n\n"
        exit 0
        ;;
    esac
  done
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

Assess the following ${title} skills and apply any that are relevant to completing the user's request.

CRITICAL REQUIREMENT: Before applying any skill, you MUST use the Read tool to read the full contents of the skill file at the provided path. Do not assume the skill's behavior from its title or description alone.

If operating in Plan Mode, explicitly reference specific skills and subagents within the plan contents and TODOs.

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

if [[ "$RUN_CATEGORIES" == "true" ]]; then
  cmd_categories
  exit 0
fi

printf "\n🔄 Cursor Skill Command Sync v%s\n\n" "$VERSION"

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
  printf "  ↺ Updated:  %s\n" "${OUTPUT_FILE/#$HOME/~}"
else
  printf "  ✓ Generated: %s\n" "${OUTPUT_FILE/#$HOME/~}"
fi
printf "  Skills:    %d indexed\n" "$count_found"
if [[ $count_dupes -gt 0 ]]; then
  printf "  Dupes:     %d skill(s) skipped (covered by higher-priority source)\n" "$count_dupes"
fi
printf "\n  Tip: type /skill-tags in Cursor chat to load the full skills reference.\n\n"
