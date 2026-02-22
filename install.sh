#!/usr/bin/env bash
# install.sh
# One-line installer for skill-tags.
#
# Usage (curl):
#   curl -fsSL https://raw.githubusercontent.com/stevenlight/skill-tags/main/install.sh | bash
#
# Usage (local):
#   bash install.sh

set -euo pipefail

REPO="https://raw.githubusercontent.com/stevenlight/skill-tags/main"
SYNC_SCRIPT_DEST="${HOME}/.cursor/sync-skill-commands.sh"
CURSOR_COMMANDS_DIR="${HOME}/.cursor/commands"
WRAPPER_MARKER="# ─── skill-tags / Cursor Skill Command Sync"

# ─── Helpers ───────────────────────────────────────────────────────────────────

info()    { printf "  %s\n" "$*"; }
success() { printf "  ✓ %s\n" "$*"; }
warn()    { printf "  ⚠ %s\n" "$*"; }
die()     { printf "\n  ✗ Error: %s\n\n" "$*" >&2; exit 1; }

# ─── Shell detection ───────────────────────────────────────────────────────────

detect_rc() {
  local shell_name
  shell_name="$(basename "${SHELL:-bash}")"
  if [[ "$shell_name" == "zsh" ]]; then
    echo "${HOME}/.zshrc"
  elif [[ "$shell_name" == "bash" ]]; then
    # macOS uses ~/.bash_profile, Linux uses ~/.bashrc
    if [[ "$(uname)" == "Darwin" ]]; then
      echo "${HOME}/.bash_profile"
    else
      echo "${HOME}/.bashrc"
    fi
  else
    echo "${HOME}/.profile"
  fi
}

# ─── Download or copy sync.sh ──────────────────────────────────────────────────

install_sync_script() {
  mkdir -p "$(dirname "$SYNC_SCRIPT_DEST")"
  mkdir -p "$CURSOR_COMMANDS_DIR"

  # If running from a local clone, copy directly
  local script_dir
  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd || echo "")"

  if [[ -n "$script_dir" && -f "${script_dir}/sync.sh" ]]; then
    cp "${script_dir}/sync.sh" "$SYNC_SCRIPT_DEST"
    info "Installed from local copy."
  else
    # Download from GitHub
    if command -v curl &>/dev/null; then
      curl -fsSL "${REPO}/sync.sh" -o "$SYNC_SCRIPT_DEST"
    elif command -v wget &>/dev/null; then
      wget -qO "$SYNC_SCRIPT_DEST" "${REPO}/sync.sh"
    else
      die "Neither curl nor wget found. Please install one and retry."
    fi
    info "Downloaded sync.sh from GitHub."
  fi

  chmod +x "$SYNC_SCRIPT_DEST"
  success "Installed: ${SYNC_SCRIPT_DEST/#$HOME/~}"
}

# ─── Shell wrapper ─────────────────────────────────────────────────────────────

install_wrapper() {
  local rc_file="$1"

  # Idempotent: skip if already installed
  if grep -q "$WRAPPER_MARKER" "$rc_file" 2>/dev/null; then
    warn "Shell wrapper already present in ${rc_file/#$HOME/~} — skipping."
    return 0
  fi

  # Create rc file if it doesn't exist
  touch "$rc_file"

  cat >> "$rc_file" <<'WRAPPER'

# ─── skill-tags / Cursor Skill Command Sync ────────────────────────────────────
# Wraps `npx skills` to auto-generate @skill-name.md command files after install.
# Run manually: skill-tags   (or: bash ~/.cursor/sync-skill-commands.sh)
function skills() {
  npx skills "$@"
  local exit_code=$?
  if [[ "$1" == "add" && $exit_code -eq 0 ]]; then
    bash ~/.cursor/sync-skill-commands.sh
  fi
  return $exit_code
}
# ─────────────────────────────────────────────────────────────────────────────
WRAPPER

  success "Added skills wrapper to ${rc_file/#$HOME/~}"
}

# ─── Main ──────────────────────────────────────────────────────────────────────

printf "\n🔧 Installing skill-tags...\n\n"

# 1. Install sync script
install_sync_script

# 2. Detect shell and install wrapper
RC_FILE="$(detect_rc)"
info "Detected shell rc: ${RC_FILE/#$HOME/~}"
install_wrapper "$RC_FILE"

# 3. Run initial sync
printf "\n  Running initial sync...\n"
bash "$SYNC_SCRIPT_DEST" || true

# ─── Done ──────────────────────────────────────────────────────────────────────

printf "  Installation complete!\n\n"
printf "  Next steps:\n"
printf "    1. Reload your shell:  source %s\n" "${RC_FILE/#$HOME/~}"
printf "    2. Install a skill:    skills add <owner/repo/skill-name>\n"
printf "    3. Use in Cursor chat: @<skill-name>.md\n\n"
printf "  To sync manually at any time:\n"
printf "    bash ~/.cursor/sync-skill-commands.sh\n\n"
