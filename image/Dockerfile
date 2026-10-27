# Overmind for Railway: upstream's backend image plus the Console, served together.
# Build contexts: `upstream` = overmind-core/overmind checked out at OVERMIND_REF,
# BASE = upstream's own Dockerfile built from that checkout (see .github/workflows/build.yml).
ARG BASE

FROM oven/bun:1.3.5 AS console
WORKDIR /app
COPY --from=upstream frontend/package.json frontend/bun.lock ./
RUN bun install --frozen-lockfile
COPY --from=upstream frontend/ ./
# .env.production carries the hosted Clerk key, PostHog key and api.overmindlab.ai.
# The placeholder is swapped for the deployment's public URL at boot (start.sh).
RUN rm -f .env .env.* \
    && VITE_API_BASE_URL=__OVERMIND_PUBLIC_URL__ \
       VITE_SELF_HOSTED=true \
       VITE_CLERK_PUBLISHABLE_KEY= \
       VITE_FEATURE_DATASETS=true \
       VITE_FEATURE_EVALUATIONS=true \
       VITE_FEATURE_FINETUNING=true \
       VITE_FEATURE_INFERENCE=true \
       VITE_FEATURE_MCP=true \
       VITE_FEATURE_SIGNALS=false \
       bun run build \
    && grep -rq __OVERMIND_PUBLIC_URL__ dist/assets

FROM caddy:2.10.2 AS caddy

FROM ${BASE}
COPY --from=caddy /usr/bin/caddy /usr/local/bin/caddy
COPY --from=console /app/dist /srv/console
COPY Caddyfile /etc/caddy/Caddyfile
COPY start.sh /usr/local/bin/overmind-start
COPY patch_signup.py /tmp/patch_signup.py
RUN python /tmp/patch_signup.py && rm /tmp/patch_signup.py && chmod +x /usr/local/bin/overmind-start
# Empty, not unset: unset makes STATIC_URL the hosted CDN; Caddy serves /code/static instead.
ENV AWS_S3_CUSTOM_DOMAIN=""
# Upstream's collectstatic step is swallowed because settings refuse to load without the
# required keys. Placeholders only exist for this build step.
RUN env SANDBOX_URL=x SANDBOX_TOKEN=x OPENROUTER_API_KEY=x MODAL_TOKEN_ID=x MODAL_TOKEN_SECRET=x \
        INFERENCE_API_URL=x INFERENCE_API_KEY=x AWS_ACCESS_KEY_ID=x AWS_SECRET_ACCESS_KEY=x \
        AWS_BUCKET_NAME=x HF_TOKEN=x DATA_ROOT=/tmp/build-data \
        python manage.py collectstatic --noinput \
    && rm -rf /tmp/build-data && test -d /code/static/admin
EXPOSE 8080
ENTRYPOINT []
CMD ["/usr/local/bin/overmind-start"]
