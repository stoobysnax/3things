#!/bin/bash
# One-line installer for 3 Today.
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

# Ask GitHub for the newest version by its exact id, so a cached download can't give an old one.
SHA="$(curl -fsSL "https://api.github.com/repos/stoobysnax/3things/commits/${BRANCH}" 2>/dev/null \
  | grep -m1 '"sha"' | sed -E 's/.*"sha": *"([0-9a-f]+)".*/\1/' || true)"
REF="${SHA:-$BRANCH}"
echo "Downloading version ${REF:0:7}…"
curl -fsSL "https://github.com/stoobysnax/3things/archive/${REF}.tar.gz" | tar -xz -C "$TMP" --strip-components=1
cd "$TMP"

echo "Building (takes a minute)…"
BUILD="${REF:0:7}" ./scripts/build-app.sh 2>&1 | grep -iE "error|warning: unable" || true
[[ -d "build/3 Today.app" ]] || { echo "Build failed. Copy the text above and send it to Claude."; exit 1; }

pkill -x ThreeThings 2>/dev/null || true
rm -rf "/Applications/3 Things.app" "/Applications/3 Today.app"   # 3 Things is the old name
cp -R "build/3 Today.app" /Applications/
open "/Applications/3 Today.app"
echo "Installed 3 Today (version ${REF:0:7}). The first time you set an alarm, click Allow when macOS asks about notifications."
