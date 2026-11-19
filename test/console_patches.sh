#!/bin/bash
# The Console stage runs `bun install --frozen-lockfile` before copying the rest of
# frontend/. If upstream's package.json has patchedDependencies, the patch files must be
# copied before that install, or bun fails. Usage: test/console_patches.sh [frontend_dir]
# (default: fetch package.json at OVERMIND_REF from the workflow through the GitHub API).
set -euo pipefail
HERE=$(cd "$(dirname "$0")/.." && pwd)
REF=$(sed -n 's/^ *OVERMIND_REF: *//p' "$HERE/.github/workflows/build.yml")
if [ -n "${1:-}" ]; then pkg=$(cat "$1/package.json"); else
  pkg=$(gh api "repos/overmind-core/overmind/contents/frontend/package.json?ref=$REF" -H 'Accept: application/vnd.github.raw'); fi
patches=$(printf '%s' "$pkg" | python3 -c 'import json,sys; print("\n".join(json.load(sys.stdin).get("patchedDependencies",{}).values()))')
[ -z "$patches" ] && { echo "ok no patchedDependencies at $REF"; exit 0; }
# Everything COPYed from console-src before the install line.
pre=$(awk '/^RUN bun install/{exit} /^COPY --from=console-src/' "$HERE/image/Dockerfile")
for p in $patches; do
  dir=${p%%/*}
  printf '%s\n' "$pre" | grep -qE "(^| )($p|$dir/?)( |$)" || { echo "FAIL: $p not copied before bun install ($REF)"; exit 1; }
done
echo "ok patchedDependencies copied before bun install ($REF)"
