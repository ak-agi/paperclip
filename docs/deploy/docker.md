---
title: Docker
summary: Deploy Paperclip with Docker Compose
---

Run Paperclip in Docker without installing Node or pnpm locally.

## Quick Install (Recommended)

Deploy on any Linux server with Docker installed. No git clone required.

```sh
mkdir paperclip && cd paperclip
curl -sLO https://raw.githubusercontent.com/ak-agi/paperclip/master/docker/install/docker-compose.yml
curl -sLO https://raw.githubusercontent.com/ak-agi/paperclip/master/docker/install/.env.example
curl -sLO https://raw.githubusercontent.com/ak-agi/paperclip/master/docker/install/setup.sh
chmod +x setup.sh && ./setup.sh
```

The setup script auto-generates secrets, requires an explicit public URL choice, and starts the stack. The install compose defaults to `ghcr.io/ak-agi/paperclip`. Open your configured `PAPERCLIP_PUBLIC_URL`.

### Manual Setup

```sh
cp .env.example .env
# Generate secrets:
#   openssl rand -hex 32   → BETTER_AUTH_SECRET
#   openssl rand -hex 16   → POSTGRES_PASSWORD
# Set PAPERCLIP_PUBLIC_URL to the exact browser-facing URL
# (for example https://desk.example.com or http://localhost:3100)
docker compose up -d
```

## Upgrading

```sh
docker compose pull
docker compose up -d
```

## Backup and Restore

```sh
# Backup
docker compose exec db pg_dump -U paperclip paperclip > backup.sql

# Restore
docker compose exec -T db psql -U paperclip paperclip < backup.sql
```

## Environment Variables

| Variable | Required | Default | Purpose |
|----------|----------|---------|---------|
| `BETTER_AUTH_SECRET` | Yes | — | Auth signing secret |
| `POSTGRES_PASSWORD` | Yes | — | Database password |
| `PAPERCLIP_PUBLIC_URL` | Yes | — | Exact URL users access in browser; used for auth callbacks |
| `PAPERCLIP_PORT` | No | `3100` | Host port mapping |
| `PAPERCLIP_IMAGE` | No | `ghcr.io/ak-agi/paperclip` | Image repository to pull |
| `PAPERCLIP_VERSION` | No | `latest` | Image tag to pull |
| `OPENAI_API_KEY` | No | — | Enable Codex adapter |
| `ANTHROPIC_API_KEY` | No | — | Enable Claude adapter |

## Data Persistence

All data is persisted via named Docker volumes:

- `pgdata` — PostgreSQL database
- `paperclip-data` — uploaded assets, secrets key, agent workspace data

## Building from Source (Development)

For development with a local build:

```sh
# Quickstart (embedded PGlite, no external database)
BETTER_AUTH_SECRET=$(openssl rand -hex 32) \
  docker compose -f docker/docker-compose.quickstart.yml up --build

# Full stack with PostgreSQL
BETTER_AUTH_SECRET=$(openssl rand -hex 32) \
  docker compose -f docker/docker-compose.yml up --build
```

## Claude and Codex Adapters

The Docker image pre-installs the Claude and Codex CLIs. Pass `OPENAI_API_KEY` and/or `ANTHROPIC_API_KEY` via the `.env` file or environment to enable local adapter runs inside the container.

Without API keys, the app runs normally — adapter environment checks will surface missing prerequisites.
