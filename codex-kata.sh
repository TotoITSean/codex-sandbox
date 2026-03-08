#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────
# codex-kata.sh — Launch Codex in a Kata/Firecracker microVM
# ─────────────────────────────────────────────────────────
# Linux equivalent of codex.bat, using the kata-fc runtime.
# No --privileged needed — Kata provides VM-level isolation.
#
# Usage:  ./codex-kata.sh
# ─────────────────────────────────────────────────────────
set -euo pipefail

COMPOSE_FILE="docker/docker-compose.kata.yaml"
CONTAINER_NAME="codex-kata-session"

# ── Pre-flight checks ────────────────────────────────────

if [[ ! -e /dev/kvm ]]; then
    echo "ERROR: /dev/kvm not found. Kata/Firecracker requires KVM."
    echo "Run on bare metal or a VM with nested virtualisation enabled."
    exit 1
fi

if ! docker info 2>/dev/null | grep -q 'kata-fc'; then
    if ! docker info 2>/dev/null | grep -q 'Runtimes.*kata'; then
        echo "WARNING: kata-fc runtime not found in Docker. Run sudo ./kata-setup.sh first."
        echo ""
        read -rp "Continue anyway? (y/N): " yn
        [[ "$yn" =~ ^[Yy]$ ]] || exit 1
    fi
fi

# ── Stop orphaned container from a previous session ──────

if docker container inspect -f '{{.State.Running}}' "$CONTAINER_NAME" 2>/dev/null | grep -q true; then
    echo "Stopping previous session..."
    docker stop "$CONTAINER_NAME" >/dev/null 2>&1
fi

# ── Reuse existing container or create new ───────────────

if docker container inspect "$CONTAINER_NAME" >/dev/null 2>&1; then
    echo "Resuming session..."
    echo ""
    docker start -ai "$CONTAINER_NAME"
else
    echo "Building image..."
    echo ""
    docker compose -f "$COMPOSE_FILE" build

    echo "Starting codex in Kata/Firecracker microVM..."
    echo ""
    docker compose -f "$COMPOSE_FILE" run \
        --service-ports \
        --name "$CONTAINER_NAME" \
        codex "$@"
fi

# ── Cleanup on exit ──────────────────────────────────────

docker stop "$CONTAINER_NAME" >/dev/null 2>&1 || true

EXIT_CODE=$?
if [[ $EXIT_CODE -ne 0 ]]; then
    echo ""
    echo "Codex failed to start."
    echo ""
    read -rp "Remove container and retry? (y/N): " yn
    if [[ "$yn" =~ ^[Yy]$ ]]; then
        echo ""
        echo "Removing container..."
        docker rm -f "$CONTAINER_NAME" >/dev/null 2>&1 || true
        docker compose -f "$COMPOSE_FILE" down --remove-orphans

        echo ""
        echo "Rebuilding..."
        echo ""
        docker compose -f "$COMPOSE_FILE" build
        docker compose -f "$COMPOSE_FILE" run \
            --service-ports \
            --name "$CONTAINER_NAME" \
            codex "$@"
    fi
fi
