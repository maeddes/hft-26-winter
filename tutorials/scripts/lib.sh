# Helpers for the tutorial scripts. Source it, do not run it.
#
#   step "Title"        prints a section heading
#   say "text"          prints an explanation
#   run cmd args...     prints the command, then runs it; stops the script if it fails
#   fails cmd args...   prints the command, runs it, and expects it to fail
#   show "cmd"          only prints a command – for steps the script does differently
#
# PAUSE=1 waits for Enter before every command – for walking through it live.

set -euo pipefail

if [ -t 1 ]; then
  BOLD=$'\e[1m'; DIM=$'\e[2m'; CYAN=$'\e[36m'; YELLOW=$'\e[33m'; RESET=$'\e[0m'
else
  BOLD=""; DIM=""; CYAN=""; YELLOW=""; RESET=""
fi

step() {
  printf '\n%s== %s ==%s\n' "$BOLD" "$1" "$RESET"
}

say() {
  printf '%s%s%s\n' "$DIM" "$1" "$RESET"
}

show() {
  printf '\n%s$ %s%s\n' "$CYAN" "$*" "$RESET"
  if [ "${PAUSE:-0}" = "1" ]; then
    read -r -p "  (Enter) " _ </dev/tty
  fi
}

run() {
  show "$*"
  bash -c "$*"
}

fails() {
  show "$*"
  if bash -c "$*"; then
    printf '%sexpected this to fail, but it worked%s\n' "$YELLOW" "$RESET"
    exit 1
  fi
  printf '%s(failed, as expected)%s\n' "$YELLOW" "$RESET"
}

# Run from the repository root, wherever the script is called from.
cd "$(dirname "${BASH_SOURCE[0]}")/../.."
