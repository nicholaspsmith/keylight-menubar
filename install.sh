#!/usr/bin/env bash
# Build KeyLight.app and symlink it into ~/Applications (rebuilds propagate;
# SMAppService accepts a symlink there for Start-at-Login).
set -euo pipefail

SRC_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_NAME="KeyLight.app"

"$SRC_DIR/scripts/build-app.sh"

mkdir -p "$HOME/Applications"
ln -sfn "$SRC_DIR/build/$APP_NAME" "$HOME/Applications/$APP_NAME"
echo "Linked $HOME/Applications/$APP_NAME -> $SRC_DIR/build/$APP_NAME"

open "$HOME/Applications/$APP_NAME"

cat <<'EOF'

KeyLight is now running in the menu bar.

First-run setup
  1. Grant Accessibility when prompted (System Settings ▸ Privacy & Security ▸
     Accessibility). This is required to intercept the brightness keys. Until
     granted, the menu shows "⚠ Grant Accessibility…"; it auto-starts once you
     allow it.
  2. Optional: menu ▸ Start at Login.

Test (lid open): Ctrl + brightness-up / Ctrl + brightness-down changes the
keyboard backlight instead of the display. In clamshell the internal backlight
is suppressed by macOS, so test with the lid open.

Note: this is an ad-hoc-signed build, so macOS may ask you to re-grant
Accessibility after a rebuild (the code hash changes).
EOF
