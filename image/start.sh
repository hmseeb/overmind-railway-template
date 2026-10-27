#!/bin/bash
# API, Celery workers, beat and Caddy in one container: dataset files bypass Django
# storage and land on local MEDIA_ROOT, and a Railway volume attaches to one service only.
set -euo pipefail
cd /code

: "${OVERMIND_PUBLIC_URL:?set OVERMIND_PUBLIC_URL to https://<your domain>}"
grep -rl __OVERMIND_PUBLIC_URL__ /srv/console | xargs -r sed -i "s#__OVERMIND_PUBLIC_URL__#${OVERMIND_PUBLIC_URL%/}#g"

mkdir -p "${MEDIA_ROOT:-/data/media}" "${TMPDIR:-/data/tmp}"

echo "==> migrate"
python manage.py migrate --noinput

gunicorn overbae.asgi:application --worker-class uvicorn_worker.UvicornWorker \
  --workers "${WEB_CONCURRENCY:-2}" --bind 127.0.0.1:8001 --timeout 120 --graceful-timeout 30 \
  --access-logfile - &
# Upstream runs six workers; the same queues on two pools keep memory near 2 GB.
celery -A overbae worker -l info --pool=threads --concurrency="${CELERY_THREADS:-8}" \
  --hostname=threads@%h -Q control,io &
celery -A overbae worker -l info --pool=prefork --concurrency="${CELERY_PROCESSES:-2}" \
  --prefetch-multiplier=1 --hostname=prefork@%h -Q io_traces,batch,landing,interactive &
celery -A overbae beat -l info --scheduler django_celery_beat.schedulers:DatabaseScheduler &
caddy run --config /etc/caddy/Caddyfile --adapter caddyfile &

# Any process dying takes the container down so Railway restarts all of them together.
wait -n
echo "a process exited; stopping container" >&2
exit 1
