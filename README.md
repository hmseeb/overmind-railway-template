# Overmind on Railway

Railway template for [Overmind](https://github.com/overmind-core/overmind) (AGPL-3.0), the platform for continuously improving AI agents. The deployer guide is [TEMPLATE_OVERVIEW.md](TEMPLATE_OVERVIEW.md); it is also the marketplace listing.

[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/deploy/overmind)

## Layout

| Path | What |
| --- | --- |
| `template.json` | Build sheet: every service, variable and start command, with `$note` keys giving the reason for each choice. It is the master copy of the template. |
| `image/` | The `ghcr.io/hmseeb/overmind-railway` image: upstream's backend image plus the Console (built with a URL placeholder), Caddy, `start.sh` (API, workers, beat and Caddy in one container) and `patch_signup.py` (closes open sign-up after the first account). |
| `.github/workflows/build.yml` | Builds upstream's Dockerfile unmodified at `OVERMIND_REF`, then the layer above. Bump `OVERMIND_REF` for a new release, `REV` for an `image/` change. |
| `test/image.sh` | Contract checks on the built image. |
| `upsert.py` | Writes `template.json` to the Railway template (`templateUpsertConfig`) and asserts it back field by field. |
| `build_source.py`, `deploy_as_stranger.py`, `status.py` | Live verification: materialize the sheet into a project, deploy the template into a fresh project, read deploy status and logs. |

## Differences from upstream compose

- API and all Celery queues share one container: dataset files go to local `MEDIA_ROOT`, and a Railway volume attaches to one service.
- Grafana is dropped; it reads the hosted product's CloudWatch.
- Postgres serves TLS with a per-deployment self-signed cert, since settings force `sslmode=require` outside DEBUG.
- The sandbox runs as `nobody` with `SANDBOX_ALLOW_SHARED_UID=1`, since Railway grants no `CAP_SYS_PTRACE`.
- Sign-up closes after the first account and guest sessions are refused, since the URL is public.
- Fine-tuning keys are boot-check placeholders (`not-configured`).
