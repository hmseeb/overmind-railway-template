# Deploy and Host Overmind on Railway

Overmind is an open-source platform for continuously improving AI agents. Your agent sends traces through the `overmind` Python SDK or any OpenTelemetry exporter, and Overmind scores them with LLM judges, builds datasets from real runs, runs evaluations against the metrics you define, and helps you swap prompts and models for cheaper or better ones. It also ships an MCP server so Cursor, Claude Code, Codex or OpenCode can drive it from your editor.

## About Hosting Overmind

This template runs the full Overmind platform in one Railway project: the API, the Console web app, the Celery workers and scheduler, an isolated sandbox for document parsing and Data Workshop code, Postgres with pgvector, and Redis. The Console and the API share one public URL, so the SDK, the MCP server and the browser all point at the same address.

You only need one key to deploy: an OpenRouter API key, which Overmind uses for every judge, eval and scoring call. Traces, datasets and evaluation results stay in your own Postgres database and volume.

The image is built from Overmind v0.1.18 and pinned, so a redeploy never pulls a surprise upgrade.

## Common Use Cases

- Collecting production traces from your LLM agents and scoring every run automatically
- Building evaluation datasets from real conversations, documents and uploads
- Comparing prompts and models on your own metrics before shipping a change
- Keeping agent traces and training data inside infrastructure you control
- Letting a coding agent (Cursor, Claude Code, Codex, OpenCode) inspect traces and run evals over MCP

## Dependencies for Overmind Hosting

- Postgres 16 with pgvector, on a Railway volume
- Redis, as the Celery task queue
- An OpenRouter API key

### Deployment Dependencies

- [Overmind repository](https://github.com/overmind-core/overmind)
- [Overmind documentation](https://docs.overmindlab.ai)
- [OpenRouter API keys](https://openrouter.ai/keys)
- [Template source and image build](https://github.com/hmseeb/overmind-railway-template)

### Implementation Details

**First login**

1. Deploy and wait for all four services to turn green. The first boot runs the database migrations and takes two to three minutes.
2. Open the `Overmind` service's public URL.
3. Sign in with your email and a password of your choice. The first sign-in creates your account.

That first account becomes the only one. After it exists, signing in with a new email is refused, so nobody who finds your URL can create an account and spend your OpenRouter credit. Guest sessions are switched off for the same reason.

**Adding teammates**

Invite them from a project's members page. An invited email can create its account on its next sign-in. To open sign-up to anyone with the URL instead, set `OVERMIND_OPEN_SIGNUP=true` on the `Overmind` service.

**Sending your first trace**

Create a project, then create a project API key under Settings. In your agent:

```
pip install "overmind[tracing]"
export OVERMIND_API_KEY=ovr_...
export OVERMIND_API_URL=https://your-overmind.up.railway.app
```

```python
import overmind

overmind.init(service_name="support-agent", providers="auto")

with overmind.run("support-run", intent=question) as run:
    answer = agent(question)
    run.deliver(answer)
```

The trace appears under Observability within a few seconds. Any OpenTelemetry exporter can also post to `https://your-overmind.up.railway.app/api/v1/traces`.

**Connecting a coding agent over MCP**

The MCP server is at `https://your-overmind.up.railway.app/api/mcp/`. Use a project or account API key as a bearer token, or let the client sign in through OAuth.

**What works out of the box, and what needs more accounts**

| Feature | Needs |
| --- | --- |
| Tracing, Observability, projects, API keys, MCP | Nothing extra |
| Judges, evals, trace scoring, optimiser, Data Workshop | `OPENROUTER_API_KEY` (asked for at deploy) |
| Document and image uploads with OCR | Nothing extra; runs in the Sandbox service |
| `embedding_cosine` evaluator | `OPENAI_API_KEY` |
| Fine-tuning and serving trained models | A Modal account, an S3 bucket and a Hugging Face token |

Fine-tuning variables (`MODAL_TOKEN_ID`, `MODAL_TOKEN_SECRET`, `INFERENCE_API_URL`, `INFERENCE_API_KEY`, `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_BUCKET_NAME`, `HF_TOKEN`) start as `not-configured`. Overmind refuses to boot when they are empty but only reads them when you start a fine-tune, so the placeholders keep everything else working. To enable fine-tuning, replace them with real values and deploy Overmind's Modal workers as described in the upstream README.

**Custom domain**

Add the domain to the `Overmind` service, then update `OVERMIND_PUBLIC_URL`, `DJANGO_ALLOWED_HOSTS`, `DJANGO_CORS_ALLOWED_ORIGINS`, `FRONTEND_URL` and `MCP_SERVER_URL` to use it, and redeploy.

**How the services fit together**

- `Overmind` runs the API, three Celery processes (one thread pool, one process pool, and the beat scheduler) and Caddy, which serves the Console and proxies the API. They share one container because Overmind writes dataset files to local disk that the workers read back, and a Railway volume attaches to one service only. All data lives on the volume at `/data`.
- `Sandbox` parses uploaded documents and runs Data Workshop code. It holds no database access, no API keys and no volume. Railway cannot grant the ptrace capability Overmind uses to give each run its own Linux user, so runs share one unprivileged user inside this container.
- `Postgres` serves TLS with a certificate generated on first boot, because Overmind requires an encrypted database connection in production mode.
- `Redis` is only the task queue; nothing in it needs to survive a restart.

**Scaling**

Worker concurrency is set by `CELERY_THREADS` (default 8), `CELERY_PROCESSES` (default 2) and `WEB_CONCURRENCY` (API workers, default 2) on the `Overmind` service. Raise them along with the service's memory if trace volume grows. Upstream runs six separate workers; this template keeps every queue but runs them on two pools to stay near 2 GB of memory.

**Troubleshooting**

- *Judges or scores fail with `AuthenticationError`*: `OPENROUTER_API_KEY` is wrong or has no credit.
- *"Invalid email or password" for a new teammate*: sign-up is closed after the first account. Invite their email to a project first, or set `OVERMIND_OPEN_SIGNUP=true`.
- *The Django admin*: it lives at the random path in `DJANGO_ADMIN_PATH`, not `/admin/`.

## Why Deploy Overmind on Railway?

Railway is a singular platform to deploy your infrastructure stack. Railway will host your infrastructure so you don't have to deal with configuration, while allowing you to vertically and horizontally scale it.

By deploying Overmind on Railway, you are one step closer to supporting a complete full-stack application with minimal burden. Host your servers, databases, AI agents, and more on Railway.
