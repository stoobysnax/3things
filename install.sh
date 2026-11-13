#!/bin/bash
# One-line installer for 3 Things.
#   curl -fsSL https://raw.githubusercontent.com/stoobysnax/3things/main/install.sh | bash
set -euo pipefail

if ! xcode-select -p >/dev/null 2>&1 || ! command -v swift >/dev/null 2>&1; then
  echo "Apple's Command Line Tools are needed (a free, one-time install, not the Xcode app)."
  echo "A window will pop up: click Install, wait for it to finish, then run this command again."
  xcode-select --install || true
  exit 1
fi

BRANCH="${BRANCH:-main}"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
echo "Downloading…"
curl -fsSL "https://github.com/stoobysnax/3things/archive/refs/heads/${BRANCH}.tar.gz" | tar -xz -C "$TMP" --strip-components=1
cd "$TMP"

echo "Building (takes a minute)…"
./scripts/build-app.sh 2>&1 | grep -iE "error|warning: unable" || true
[[ -d "build/3 Things.app" ]] || { echo "Build failed. Copy the text above and send it to Claude."; exit 1; }

pkill -x ThreeThings 2>/dev/null || true
rm -rf "/Applications/3 Things.app"
cp -R "build/3 Things.app" /Applications/
open "/Applications/3 Things.app"
echo "Installed 3 Things. The first time you set an alarm, click Allow when macOS asks about notifications."
