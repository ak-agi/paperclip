#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

# ── Dependency checks ──────────────────────────────────────────────
check_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "ERROR: '$1' is required but not found. Please install it first." >&2
    exit 1
  fi
}

check_cmd docker

if ! docker compose version >/dev/null 2>&1; then
  echo "ERROR: 'docker compose' plugin is required (Docker Compose V2)." >&2
  echo "       Install: https://docs.docker.com/compose/install/" >&2
  exit 1
fi

if ! docker info >/dev/null 2>&1; then
  echo "ERROR: Docker daemon is not running, or current user lacks permission." >&2
  echo "       Try: sudo systemctl start docker && sudo usermod -aG docker \$USER" >&2
  exit 1
fi

# ── Secret generation helper ───────────────────────────────────────
generate_hex() {
  local length="${1:-32}"
  if command -v openssl >/dev/null 2>&1; then
    openssl rand -hex "$length"
  else
    head -c "$length" /dev/urandom | xxd -p | tr -d '\n'
  fi
}

# ── Create .env from template ─────────────────────────────────────
if [ -f .env ]; then
  echo "Found existing .env — preserving it."
else
  if [ ! -f .env.example ]; then
    echo "ERROR: .env.example not found in $SCRIPT_DIR" >&2
    exit 1
  fi
  cp .env.example .env
  echo "Created .env from .env.example"
fi

# ── Fill in missing secrets ────────────────────────────────────────
fill_secret() {
  local key="$1" length="$2"
  if grep -qE "^${key}=$" .env; then
    local val
    val="$(generate_hex "$length")"
    sed -i "s|^${key}=$|${key}=${val}|" .env
    echo "  Generated ${key}"
  fi
}

echo "Checking secrets..."
fill_secret BETTER_AUTH_SECRET 32
fill_secret POSTGRES_PASSWORD 16

# ── Prompt for public URL ──────────────────────────────────────────
current_url=$(grep -E '^PAPERCLIP_PUBLIC_URL=' .env | cut -d= -f2-)
current_port=$(grep -E '^PAPERCLIP_PORT=' .env | cut -d= -f2-)
if [ -z "${current_port:-}" ]; then
  current_port=3100
fi
localhost_url="http://localhost:${current_port}"
if [ -z "$current_url" ] || [ "$current_url" = "http://localhost:3100" ] || [ "$current_url" = "$localhost_url" ]; then
  echo ""
  echo "Paperclip needs a public URL for auth callbacks."
  echo "Enter the exact URL users will open in their browser."
  echo "For a remote Ubuntu server, this should normally be your public domain, e.g. https://desk.example.com."
  while true; do
    read -r -p "Public URL [${localhost_url}]: " user_url
    if [ -z "$user_url" ]; then
      echo ""
      echo "Using ${localhost_url} only works when the browser is on this same machine."
      read -r -p "Use ${localhost_url}? [y/N]: " confirm_localhost
      case "${confirm_localhost}" in
        y|Y|yes|YES)
          user_url="$localhost_url"
          ;;
        *)
          continue
          ;;
      esac
    fi

    # Do not pass user_url through sed replacement: & \ and the | delimiter break sed.
    tmp="$(mktemp)"
    awk -v url="$user_url" '
      /^PAPERCLIP_PUBLIC_URL=/ { print "PAPERCLIP_PUBLIC_URL=" url; next }
      { print }
    ' .env >"$tmp" && mv "$tmp" .env
    echo "  Set PAPERCLIP_PUBLIC_URL=${user_url}"
    break
  done
fi

echo ""
echo "Configuration complete. Starting Paperclip..."
echo ""
docker compose up -d

echo ""
echo "────────────────────────────────────────────"
echo "  Paperclip is starting!"
echo ""
echo "  Check status:  docker compose ps"
echo "  View logs:     docker compose logs -f"
echo "  Open:          $(grep -E '^PAPERCLIP_PUBLIC_URL=' .env | cut -d= -f2-)"
echo "────────────────────────────────────────────"
