#!/bin/bash
# Railway's in-place restarts keep the container filesystem, so image/start.sh must boot
# on the 2nd and 3rd start of the same container (the Console placeholder is already gone).
# Runs start.sh against a temp tree with stub binaries; no image or database needed.
set -uo pipefail
HERE=$(cd "$(dirname "$0")/.." && pwd)
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
mkdir -p "$T/code" "$T/console/assets" "$T/bin" "$T/data"
echo 'fetch("__OVERMIND_PUBLIC_URL__/api")' > "$T/console/assets/app.js"
for b in python gunicorn celery caddy; do printf '#!/bin/sh\nexit 0\n' > "$T/bin/$b"; chmod +x "$T/bin/$b"; done
# The image has GNU sed; on macOS map `sed -i EXPR` to BSD's `sed -i '' EXPR`.
if [ "$(uname)" = Darwin ]; then
  printf '#!/bin/sh\n[ "$1" = -i ] && { shift; exec /usr/bin/sed -i "" "$@"; }\nexec /usr/bin/sed "$@"\n' > "$T/bin/sed"
  chmod +x "$T/bin/sed"
fi
sed -e "s#/srv/console#$T/console#g" -e "s#^cd /code#cd $T/code#" "$HERE/image/start.sh" > "$T/start.sh"
for n in 1 2 3; do
  out=$(PATH="$T/bin:$PATH" OVERMIND_PUBLIC_URL=https://example.test/ MEDIA_ROOT="$T/data/m" TMPDIR="$T/data/t" \
        bash "$T/start.sh" 2>&1)
  grep -q '==> migrate' <<<"$out" || { echo "FAIL: start $n exited before migrate"; exit 1; }
done
grep -q 'fetch("https://example.test/api")' "$T/console/assets/app.js" || { echo "FAIL: placeholder not substituted"; exit 1; }
echo "ok start.sh boots on starts 1-3 of the same filesystem"
