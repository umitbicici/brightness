#!/bin/sh
# Sets the app version and bumps the build number (Sparkle compares build
# numbers, so every release needs a higher one).
# Usage: scripts/set-version.sh 0.2.0
set -eu
cd "$(dirname "$0")/.."

VERSION="${1:-}"
case "$VERSION" in
  [0-9]*.[0-9]*.[0-9]*) ;;
  *) echo "Usage: scripts/set-version.sh <x.y.z>" >&2; exit 1 ;;
esac

BUILD=$(sed -n 's/^    CURRENT_PROJECT_VERSION: \([0-9]*\)$/\1/p' project.yml)
NEXT=$((BUILD + 1))
sed -i '' \
  -e "s/^    MARKETING_VERSION: .*/    MARKETING_VERSION: $VERSION/" \
  -e "s/^    CURRENT_PROJECT_VERSION: .*/    CURRENT_PROJECT_VERSION: $NEXT/" \
  project.yml
echo "Version $VERSION (build $NEXT)"
