#!/usr/bin/env bash
# Quick rollback launcher
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "$SCRIPT_DIR/scripts/rollback_atomic64.sh" "$@"
