#!/bin/bash
# Contract checks on the built image (no database needed). Usage: test/image.sh [image]
set -euo pipefail
IMG=${1:-ghcr.io/hmseeb/overmind-railway:latest}
run() { docker run --rm --platform linux/amd64 --entrypoint /bin/sh "$IMG" -c "$1"; }
run 'PORT=8080 caddy validate --config /etc/caddy/Caddyfile --adapter caddyfile' && echo "ok caddyfile"
run 'grep -q OVERMIND_OPEN_SIGNUP /code/overbae/api/auth_registration.py' && echo "ok signup guard"
run 'grep -rq __OVERMIND_PUBLIC_URL__ /srv/console/assets && test -f /srv/console/index.html' && echo "ok console placeholder"
run '! grep -rq "pk_live_\|api.overmindlab.ai" /srv/console/assets' && echo "ok no hosted keys in console"
run 'test -f /code/static/admin/css/base.css' && echo "ok static collected"
run 'command -v setpriv celery gunicorn bash >/dev/null' && echo "ok binaries"
