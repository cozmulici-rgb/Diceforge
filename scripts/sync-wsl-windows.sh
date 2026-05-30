#!/usr/bin/env bash
# sync-wsl-windows.sh
# Syncs Diceforge between WSL native filesystem and Windows filesystem.
# Excludes .git so each repo keeps its own git history.
# Usage:
#   ./scripts/sync-wsl-windows.sh wsl2win   # WSL → Windows
#   ./scripts/sync-wsl-windows.sh win2wsl   # Windows → WSL
#   ./scripts/sync-wsl-windows.sh status    # show diff summary (no changes)

set -euo pipefail

WSL_DIR="/home/cozmu/projects/Diceforge"
WIN_DIR="/mnt/c/Users/cozmu/projects/Diceforge"

RSYNC_OPTS=(
  -av
  --delete
  --exclude='.git/'
  --exclude='dist/'
  --exclude='*.pyc'
  --exclude='__pycache__/'
  --exclude='*.tmp'
)

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

usage() {
  echo -e "${YELLOW}Usage:${NC} $0 <direction>"
  echo ""
  echo "  wsl2win   Copy WSL → Windows (WSL is source of truth)"
  echo "  win2wsl   Copy Windows → WSL (Windows is source of truth)"
  echo "  status    Show what would change (dry-run, no files modified)"
  echo ""
  echo "Paths:"
  echo "  WSL:     $WSL_DIR"
  echo "  Windows: $WIN_DIR"
}

check_dirs() {
  if [[ ! -d "$WSL_DIR" ]]; then
    echo -e "${RED}ERROR:${NC} WSL directory not found: $WSL_DIR"
    exit 1
  fi
  if [[ ! -d "$WIN_DIR" ]]; then
    echo -e "${RED}ERROR:${NC} Windows directory not found: $WIN_DIR"
    exit 1
  fi
}

warn_git() {
  local src="$1"
  if [[ -n "$(git -C "$src" status --porcelain 2>/dev/null)" ]]; then
    echo -e "${YELLOW}⚠ Warning:${NC} '$src' has uncommitted changes."
    echo "   Consider committing before syncing to avoid confusion."
    echo ""
    read -r -p "Continue anyway? [y/N] " confirm
    [[ "$confirm" =~ ^[Yy]$ ]] || { echo "Aborted."; exit 0; }
  fi
}

case "${1:-}" in
  wsl2win)
    check_dirs
    warn_git "$WSL_DIR"
    echo -e "${GREEN}▶ Syncing WSL → Windows${NC}"
    rsync "${RSYNC_OPTS[@]}" "$WSL_DIR/" "$WIN_DIR/"
    echo -e "${GREEN}✔ Done.${NC} Windows copy is now in sync with WSL."
    ;;
  win2wsl)
    check_dirs
    warn_git "$WIN_DIR"
    echo -e "${GREEN}▶ Syncing Windows → WSL${NC}"
    rsync "${RSYNC_OPTS[@]}" "$WIN_DIR/" "$WSL_DIR/"
    echo -e "${GREEN}✔ Done.${NC} WSL copy is now in sync with Windows."
    ;;
  status)
    check_dirs
    echo -e "${YELLOW}▶ Dry-run diff (WSL → Windows):${NC}"
    rsync "${RSYNC_OPTS[@]}" --dry-run --itemize-changes "$WSL_DIR/" "$WIN_DIR/" \
      | grep -v "^sending\|^sent\|^total" || true
    echo ""
    echo -e "${YELLOW}Tip:${NC} Run 'wsl2win' or 'win2wsl' to apply changes."
    ;;
  *)
    usage
    exit 1
    ;;
esac
