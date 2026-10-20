# Hindsight container facts

Research for issue #2 (map #1). Researched 2026-10-21. Latest release at the time: `v1.0.0` (2026-10-13), previous `v0.10.3`.

Sources (primary only):

- [Installation] https://hindsight.vectorize.io/developer/installation (repo: `hindsight-docs/docs/developer/installation.md`)
- [Config] https://hindsight.vectorize.io/developer/configuration (repo: `hindsight-docs/docs/developer/configuration.mdx`)
- [Monitoring] https://hindsight.vectorize.io/developer/monitoring
- [Dockerfile] `docker/standalone/Dockerfile` in github.com/vectorize-io/hindsight (main)
- [start-all] `docker/standalone/start-all.sh` in the same repo
- [README] https://github.com/vectorize-io/hindsight

## Image, registry, tags

- Registry/image: `ghcr.io/vectorize-io/hindsight` (GitHub Container Registry). [README, Installation]
- All-in-one image (API + Control Plane) is the `standalone` Dockerfile stage; `HINDSIGHT_ENABLE_API=true` and `HINDSIGHT_ENABLE_CP=true` by default. [Dockerfile]
- Tag scheme [Installation]:
  - `latest` full image (bundles local embedding + reranker models): about 9 GB amd64, 3.7 GB arm64.
  - `latest-slim` slim image: about 500 MB; needs external embedding and reranker providers. (The size table calls it `slim`; the tag list says `latest-slim`.)
  - Pinned: `X.Y.Z` and `X.Y.Z-slim` (docs example `0.4.9`; current releases are `0.10.x` / `1.0.0`, so verify the exact tag exists before pinning).
  - Separate images `hindsight-api` and `hindsight-control-plane` also exist (out of scope per map).
  - Images signed with Cosign (verification optional).
- The Docker images do not include llama.cpp, so the `llamacpp` provider is unavailable in Docker. [Installation]
- Resource sizing exists in Installation (slim API: 512 MB min / 1 GB recommended). `--shm-size=1g` is in the official run command.

## Official run command [Installation]

```bash
docker run -it --pull always --name hindsight --restart unless-stopped --shm-size=1g \
  -p 8888:8888 -p 9999:9999 \
  -e HINDSIGHT_API_LLM_API_KEY=$OPENAI_API_KEY \
  -v hindsight-data:/home/hindsight/.pg0 \
  ghcr.io/vectorize-io/hindsight:latest
```

## Ports

- 8888: API (`HINDSIGHT_API_PORT`, default 8888). 9999: Control Plane (`HINDSIGHT_CP_PORT`, default 9999). [Config, start-all]
- `HINDSIGHT_API_HOST` default `0.0.0.0` (inside container). `HINDSIGHT_CP_HOSTNAME` default `0.0.0.0`. [Config, start-all]
- Worker ports (8889) only apply to the separate worker; out of scope. [Monitoring]
- Gotcha: `HINDSIGHT_CP_HOSTNAME` set to a literal loopback (`127.0.0.1`, `::1`) is rewritten by start-all.sh to `localhost` with a pinned DNS order, because Next.js otherwise 307-loops pages (issue #1926). Inside the container leave it at `0.0.0.0` and restrict exposure via the Docker port mapping (`-p 127.0.0.1:8888:8888`) instead. [start-all]

## Env vars for a single-container deploy

Required: `HINDSIGHT_API_LLM_API_KEY` (unless provider is `none`/keyless such as ollama). [Installation, Config]

Entrypoint/container (start-all.sh) [Dockerfile, start-all]:

| Var | Default | Note |
|---|---|---|
| `HINDSIGHT_ENABLE_API` | `true` | |
| `HINDSIGHT_ENABLE_CP` | `true` (standalone) | |
| `HINDSIGHT_CP_DATAPLANE_API_URL` | `http://localhost:8888` | CP to API |
| `HINDSIGHT_CP_PORT` | `9999` | |
| `HINDSIGHT_CP_HOSTNAME` | `0.0.0.0` | see gotcha above |
| `HINDSIGHT_API_STARTUP_WAIT_SECONDS` | 300, or `MODEL_INIT_TIMEOUT`+30 if larger | wrapper kills the container if API `/health` is not up in time |
| `HINDSIGHT_API_HEALTH_URL` | `http://localhost:${PORT}/health` | wrapper probe target |
| `HINDSIGHT_WAIT_FOR_DEPS` | `false` | opt-in wait for dependencies |

API [Config]:

| Var | Default | Note |
|---|---|---|
| `HINDSIGHT_API_LLM_PROVIDER` | `openai` | |
| `HINDSIGHT_API_LLM_API_KEY` | none | secret |
| `HINDSIGHT_API_LLM_MODEL` | `gpt-5-mini` | |
| `HINDSIGHT_API_LLM_BASE_URL` | provider default | custom endpoint |
| `HINDSIGHT_API_DATABASE_URL` | `pg0` (embedded) | external: `postgresql://user:pass@host:5432/db` |
| `HINDSIGHT_API_DATABASE_SCHEMA` | `public` | |
| `HINDSIGHT_API_RUN_MIGRATIONS_ON_STARTUP` | `true` | |
| `HINDSIGHT_API_VECTOR_EXTENSION` | `pgvector` | options `pgvector`, `vchord`, `pgvectorscale`, `scann` |
| `HINDSIGHT_API_WORKER_ID` | container hostname | set a stable value (see gotchas) |
| `HINDSIGHT_API_LOG_LEVEL` / `_LOG_FORMAT` | `info` / `text` (`json` available) | |
| `HINDSIGHT_API_MODEL_INIT_TIMEOUT` | `300` s | raise for first-run model download |
| `HINDSIGHT_API_MCP_ENABLED` | `true` | |
| `HINDSIGHT_API_TENANT_EXTENSION` | none (auth off) | set to `hindsight_api.extensions.builtin.tenant:ApiKeyTenantExtension` to require an API key |
| `HINDSIGHT_API_TENANT_API_KEY` | none | clients send `Authorization: Bearer <key>`; 401 otherwise |
| `HINDSIGHT_API_EMBEDDINGS_PROVIDER` | `local` | slim image needs external (`tei`, `openai`, `cohere`, ...) |

Control Plane [Config]:

| Var | Default | Note |
|---|---|---|
| `HINDSIGHT_CP_ACCESS_KEY` | none (login gate off) | protects UI; this is the "Control Plane access key" |
| `HINDSIGHT_CP_DATAPLANE_API_KEY` | none | bearer sent CP to API; must equal `HINDSIGHT_API_TENANT_API_KEY` if API auth is enabled |
| `HINDSIGHT_CP_MAX_UPLOAD_SIZE` | `100mb` | |

Full lists (hundreds of vars: per-operation `RETAIN_LLM_*`, `REFLECT_LLM_*`, pool tuning, embeddings, ...) are in [Config]; the table above is the single-container subset.

## LLM providers and custom base URL

- `HINDSIGHT_API_LLM_PROVIDER` options per [Config]: `openai`, `openai-responses`, `openai-codex`, `claude-code`, `cursor`, `github-copilot`, `anthropic`, `gemini`, `groq`, `minimax`, `deepseek`, `zai`, `opencode-go`, `meta`, `nous`, `xai-oauth`, `fireworks`, `ollama`, `ollama-cloud`, `lmstudio`, `llamacpp`, `vertexai`, `bedrock`, `litellm`, `litellmrouter`, `volcano`, `openrouter`, `requesty`, `none`. README says 25+ providers.
- Custom base URL: `HINDSIGHT_API_LLM_BASE_URL` (e.g. `http://localhost:11434/v1` for Ollama, `http://localhost:1234/v1` for LM Studio). [Config]
- Extra: `HINDSIGHT_API_LLM_EXTRA_BODY`, `HINDSIGHT_API_LLM_DEFAULT_HEADERS`; Vertex AI uses `HINDSIGHT_API_LLM_VERTEXAI_*`; credentials-file providers (`openai-codex`, `claude-code`, `xai-oauth`) read files from the container home and are awkward to use in a container.
- Gotcha: with a local server on the Docker host, `localhost` inside the container is the container itself.

## Data volume and ownership

- Embedded DB (pg0) data dir: `/home/hindsight/.pg0`. [Installation, Dockerfile]
- Container runs as non-root user `hindsight`, UID 1000. [Dockerfile, Installation]
- Docker named volumes are seeded with UID 1000 ownership on first use (recommended: `-v hindsight-data:/home/hindsight/.pg0`). [start-all]
- Host bind mount: the host directory must be owned by `1000:1000` (`chown -R 1000:1000 <dir>`), else pg0 fails with `Permission denied (os error 13)`. start-all.sh pre-checks writability and exits with a message. The check is skipped when `HINDSIGHT_API_DATABASE_URL` is set. [Installation, start-all]
- Do not use `--user`/`user:`: only UID 1000 exists in `/etc/passwd`; other UIDs crash with `getpwuid(): uid not found`. So `hindsight_uid` cannot be remapped; the role must chown the host dir to 1000 (mode 755 on the parent is set by the image). [start-all]
- On-disk layout may be `instances/<name>/data/PG_VERSION` (newer) or older shapes; start-all warns (issue #675) if the dir is non-empty but has no `PG_VERSION`, which indicates data loss/corruption. [start-all]

## Vector extensions and the Embedded Database

- Four supported extensions: `pgvector` (HNSW, default), `pgvectorscale` (DiskANN), `vchord`, `scann` (AlloyDB only). Selected by `HINDSIGHT_API_VECTOR_EXTENSION`. Text search extension is separate (`HINDSIGHT_API_TEXT_SEARCH_EXTENSION`, default `native`). [Config]
- The docs do not state which of these the embedded pg0 supports. Only the default (`pgvector`) is implied; `pgvectorscale`, `vchord` and `scann` need extensions the docs describe installing via `CREATE EXTENSION` on a PostgreSQL you manage, and `scann` needs AlloyDB. Treat non-default extensions as External Database only. This is an inference, not confirmed by a primary source; a test of pg0 with `vchord` would settle it.
- Embedded DB tuning: `HINDSIGHT_API_DATABASE_URL=pg0://hindsight?max_connections=300&shared_buffers=256MB`; applies at embedded DB start, so restart. [Config]
- Docs say pg0 is "not recommended for production". [Config, Installation]

## Health and readiness

Source: [Monitoring].

- `GET /health/live` on 8888: no DB check, 200 `{"status":"alive","version":...,"uptime_seconds":...}`.
- `GET /health/ready`: runs `SELECT 1`; 200 `{"status":"healthy","database":"connected",...}` or 503.
- `GET /health`: alias of `/health/ready`.
- `GET /metrics`: Prometheus metrics on 8888.
- The Control Plane also answers `/health` (start-all comment). The all-in-one image defines no Docker `HEALTHCHECK` (the Dockerfile explicitly says the cp-only stage has none; no HEALTHCHECK instruction found in the file). The role must supply its own healthcheck (e.g. systemd `ExecStartPost` or an Ansible `uri` wait on `/health/ready`).
- First start downloads/initialises models and runs migrations: allow up to 300 s (`MODEL_INIT_TIMEOUT`).

## Restart and upgrade gotchas

- `--restart unless-stopped` and `--pull always` are in the official command. Under systemd, use `Restart=` on the unit instead and handle pulls explicitly.
- Stable worker id: default is the container hostname (container ID), which changes on every container recreation, orphaning in-flight tasks. Set `HINDSIGHT_API_WORKER_ID` (e.g. `hindsight-prod`) even for a single container. [Installation]
- Migrations run on API startup by default (`RUN_MIGRATIONS_ON_STARTUP=true`), so an image upgrade migrates the DB in place. Docs give no downgrade procedure; back up the volume or DB before bumping the tag. (Absence of a documented downgrade path is an observation about the docs.)
- Container receives SIGTERM from `docker stop` and start-all.sh forwards it to children for graceful shutdown. [start-all] Give systemd a generous `TimeoutStopSec`.
- Data survives container recreation only if the data dir is a volume. Issue #675 documents a past case of pg0 data loss despite a volume mount.
- Pin a version tag instead of `latest` for controlled upgrades. The `latest` tag moves with each release, including major bumps such as 0.10.x to 1.0.0.
- `--shm-size=1g` is in the official command; Postgres and model runtimes use shared memory (docker default is 64 MB).
- Full image is about 9 GB on amd64; plan disk and pull time on the Target Host. Offline hosts need `docker save`/`load` or a mirror.

## Open items

- Which extensions embedded pg0 can load: not documented (see above).
- Exact existence of `1.0.0` image tags was not verified against the registry; only the GitHub release was checked.
- Whether the Control Plane `/health` is the right readiness target for the CP port was not verified beyond the start-all comment.
