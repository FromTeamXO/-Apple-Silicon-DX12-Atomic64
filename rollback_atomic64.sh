#!/usr/bin/env bash
# Rollback Script for DirectX 12 Atomic64 Compatibility Layer
# Restores both CrossOver engine and bottle directories to original state.
set -euo pipefail

BOTTLE_NAME="${1:-Steam-2}"
SPECIFIC_BACKUP="${2:-}"

CX_DIR="/Applications/CrossOver.app/Contents/SharedSupport/CrossOver"
if [ ! -d "$CX_DIR" ] && [ -d "$HOME/Applications/CrossOver.app/Contents/SharedSupport/CrossOver" ]; then
    CX_DIR="$HOME/Applications/CrossOver.app/Contents/SharedSupport/CrossOver"
fi
CX_ENGINE_DLL="$CX_DIR/lib64/apple_gptk/wine/x86_64-windows/d3d12.dll"

BOTTLE_DIR="$HOME/Library/Application Support/CrossOver/Bottles/$BOTTLE_NAME"
BOTTLE_DLL="$BOTTLE_DIR/drive_c/windows/system32/d3d12.dll"
CONF_FILE="$BOTTLE_DIR/cxbottle.conf"

if [ -n "$SPECIFIC_BACKUP" ] && [ -d "$SPECIFIC_BACKUP" ]; then
    BACKUP_DIR="$SPECIFIC_BACKUP"
elif [ -d "$BOTTLE_DIR" ]; then
    BACKUP_DIR="$(find "$BOTTLE_DIR" -maxdepth 1 -type d -name "backup_atomic64_*" 2>/dev/null | sort -r | head -n 1 || true)"
else
    BACKUP_DIR=""
fi

echo "=== Rolling back Atomic64 modifications for Bottle: $BOTTLE_NAME ==="

if [ -n "$BACKUP_DIR" ] && [ -d "$BACKUP_DIR" ]; then
    echo "Restoring from backup directory: $BACKUP_DIR"
    if [ -f "$BACKUP_DIR/cx_engine_d3d12.dll.bak" ] && [ -f "$CX_ENGINE_DLL" ]; then
        echo "[1/3] Restoring CrossOver engine d3d12.dll..."
        cp "$BACKUP_DIR/cx_engine_d3d12.dll.bak" "$CX_ENGINE_DLL"
        echo "  Restored Engine SHA256: $(shasum -a 256 "$CX_ENGINE_DLL" | cut -d' ' -f1)"
    fi
    if [ -f "$BACKUP_DIR/bottle_d3d12.dll.bak" ] && [ -f "$BOTTLE_DLL" ]; then
        echo "[2/3] Restoring bottle system32 d3d12.dll..."
        cp "$BACKUP_DIR/bottle_d3d12.dll.bak" "$BOTTLE_DLL"
        echo "  Restored Bottle SHA256: $(shasum -a 256 "$BOTTLE_DLL" | cut -d' ' -f1)"
    fi
    if [ -f "$BACKUP_DIR/cxbottle.conf.bak" ] && [ -f "$CONF_FILE" ]; then
        echo "[3/3] Restoring cxbottle.conf..."
        cp "$BACKUP_DIR/cxbottle.conf.bak" "$CONF_FILE"
    fi
    echo "=== Rollback Succeeded ==="
else
    echo "ERROR: No backup directory found for bottle '$BOTTLE_NAME'."
    exit 1
fi
