#!/bin/bash
# docker.local.sh — build and run the Docker image in dev
#
# Prerequisites:
#   - env/docker.env must exist with application environment variables
#
# Usage:
#   ./docker.local.sh              # build and run
#   ./docker.local.sh build        # build only
#   ./docker.local.sh run          # run only (image must already exist)

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

IMAGE_NAME="pyre-dev"
CONTAINER_NAME="pyre-dev"
ENV_FILE="env/docker.env"

if [ ! -f "$ENV_FILE" ]; then
  echo "ERROR: $ENV_FILE not found."
  exit 1
fi

# Source env vars so build secrets are available.
set -a
source "$ENV_FILE"
set +a

# ---------------------------------------------------------------------------
# Validate required build secrets
# ---------------------------------------------------------------------------

MISSING=""

if [ -z "${SECRET_KEY_BASE:-}" ]; then
  MISSING="$MISSING  - SECRET_KEY_BASE\n"
fi

if [ -z "${PORT:-}" ]; then
  MISSING="$MISSING  - DATABASE_PATH\n"
fi

if [ -z "${DATABASE_PATH:-}" ]; then
  MISSING="$MISSING  - DATABASE_PATH\n"
fi

if [ -z "${APP_ADMIN_USER_EMAIL:-}" ]; then
  MISSING="$MISSING  - APP_ADMIN_USER_EMAIL\n"
fi

if [ -z "${APP_ADMIN_USER_PASSWORD:-}" ]; then
  MISSING="$MISSING  - APP_ADMIN_USER_PASSWORD\n"
fi

if [ -z "${SWOOSH_EMAIL_ADAPTER:-}" ]; then
  MISSING="$MISSING  - SWOOSH_EMAIL_ADAPTER\n"
fi

if [ -n "$MISSING" ]; then
  echo "ERROR: Missing required build secrets:"
  printf "$MISSING"
  echo ""
  echo "Set them in $ENV_FILE or export as env vars before running this script."
  exit 1
fi

# ---------------------------------------------------------------------------
# Build
# ---------------------------------------------------------------------------

build() {
  echo "Building $IMAGE_NAME..."
  docker build \
    -f Dockerfile \
    --secret id=SECRET_KEY_BASE,env=SECRET_KEY_BASE \
    --secret id=PORT,env=PORT \
    --secret id=PHX_HOST,env=PHX_HOST \
    --secret id=DATABASE_PATH,env=DATABASE_PATH \
    --secret id=APP_ADMIN_USER_EMAIL,env=APP_ADMIN_USER_EMAIL \
    --secret id=APP_ADMIN_USER_PASSWORD,env=APP_ADMIN_USER_PASSWORD \
    --secret id=SWOOSH_EMAIL_ADAPTER,env=SWOOSH_EMAIL_ADAPTER \
    --secret id=SWOOSH_EMAIL_API_KEY,env=SWOOSH_EMAIL_API_KEY \
    --secret id=SWOOSH_EMAIL_DOMAIN,env=SWOOSH_EMAIL_DOMAIN \
    --secret id=SWOOSH_EMAIL_FROM,env=SWOOSH_EMAIL_FROM \
    --secret id=PYRE_CLIENT_ALLOWED_PATHS,env=PYRE_CLIENT_ALLOWED_PATHS \
    --secret id=PYRE_GITHUB_REPO_URL,env=PYRE_GITHUB_REPO_URL \
    --secret id=PYRE_GITHUB_TOKEN,env=PYRE_GITHUB_TOKEN \
    --secret id=PYRE_GITHUB_BASE_BRANCH,env=PYRE_GITHUB_BASE_BRANCH \
    --secret id=PYRE_WEBSOCKET_SERVICE_TOKENS_CSV,env=PYRE_WEBSOCKET_SERVICE_TOKENS_CSV \
    --secret id=PYRE_CLIENT_CONNECTION_ID,env=PYRE_CLIENT_CONNECTION_ID \
    --secret id=PYRE_CLIENT_CONNECTION_NAME,env=PYRE_CLIENT_CONNECTION_NAME \
    --secret id=PYRE_CLIENT_ENABLED_WORKFLOWS,env=PYRE_CLIENT_ENABLED_WORKFLOWS \
    --secret id=PYRE_CLIENT_MAX_CAPACITY,env=PYRE_CLIENT_MAX_CAPACITY \
    --secret id=PYRE_CLIENT_WEBSOCKET_SERVICE_TOKEN,env=PYRE_CLIENT_WEBSOCKET_SERVICE_TOKEN \
    --secret id=PYRE_CLIENT_WEBSOCKET_URL,env=PYRE_CLIENT_WEBSOCKET_URL \
    -t "$IMAGE_NAME" .
  echo "Build complete: $IMAGE_NAME"
}

# ---------------------------------------------------------------------------
# Run
# ---------------------------------------------------------------------------

run() {
  echo "Running $CONTAINER_NAME..."
  docker run --rm \
    --name "$CONTAINER_NAME" \
    -v "$(pwd)/env/docker.env:/app/env/docker.env:ro" \
    -e SECRET_KEY_BASE="${SECRET_KEY_BASE}" \
    -e PORT="${PORT}" \
    -e PHX_HOST="${PHX_HOST}" \
    -e DATABASE_PATH="${DATABASE_PATH}" \
    -e APP_ADMIN_USER_EMAIL="${APP_ADMIN_USER_EMAIL}" \
    -e APP_ADMIN_USER_PASSWORD="${APP_ADMIN_USER_PASSWORD}" \
    -e SWOOSH_EMAIL_ADAPTER="${SWOOSH_EMAIL_ADAPTER}" \
    -e SWOOSH_EMAIL_API_KEY="${SWOOSH_EMAIL_API_KEY}" \
    -e SWOOSH_EMAIL_DOMAIN="${SWOOSH_EMAIL_DOMAIN}" \
    -e SWOOSH_EMAIL_FROM="${SWOOSH_EMAIL_FROM}" \
    -e PYRE_CLIENT_ALLOWED_PATHS="${PYRE_CLIENT_ALLOWED_PATHS}" \
    -e PYRE_GITHUB_REPO_URL="${PYRE_GITHUB_REPO_URL}" \
    -e PYRE_GITHUB_TOKEN="${PYRE_GITHUB_TOKEN}" \
    -e PYRE_GITHUB_BASE_BRANCH="${PYRE_GITHUB_BASE_BRANCH}" \
    -e PYRE_WEBSOCKET_SERVICE_TOKENS_CSV="${PYRE_WEBSOCKET_SERVICE_TOKENS_CSV}" \
    -e PYRE_CLIENT_CONNECTION_ID="${PYRE_CLIENT_CONNECTION_ID}" \
    -e PYRE_CLIENT_CONNECTION_NAME="${PYRE_CLIENT_CONNECTION_NAME}" \
    -e PYRE_CLIENT_ENABLED_WORKFLOWS="${PYRE_CLIENT_ENABLED_WORKFLOWS}" \
    -e PYRE_CLIENT_MAX_CAPACITY="${PYRE_CLIENT_MAX_CAPACITY}" \
    -e PYRE_CLIENT_WEBSOCKET_SERVICE_TOKEN="${PYRE_CLIENT_WEBSOCKET_SERVICE_TOKEN}" \
    -e PYRE_CLIENT_WEBSOCKET_URL="${PYRE_CLIENT_WEBSOCKET_URL}" \
    -p "${PORT}:${PORT}" \
    "$IMAGE_NAME"
}

# ---------------------------------------------------------------------------
# Exec
# ---------------------------------------------------------------------------

exec() {
  echo "Executing $CONTAINER_NAME..."
  docker exec -it "$CONTAINER_NAME" "$1"
}

# ---------------------------------------------------------------------------
# Shell
# ---------------------------------------------------------------------------

shell() {
  echo "Shelling into $CONTAINER_NAME..."
  docker exec -it "$CONTAINER_NAME" /bin/bash
}

# ---------------------------------------------------------------------------
# Entrypoint
# ---------------------------------------------------------------------------

case "${1:-}" in
  build) build ;;
  run)   run ;;
  exec)  exec "$2" ;;
  shell) shell;;
  *)     build && run ;;
esac
