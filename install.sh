#!/usr/bin/env bash
# Quick installation launcher
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "$SCRIPT_DIR/scripts/install_atomic64.sh" "$@"
