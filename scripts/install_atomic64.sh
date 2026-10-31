#!/usr/bin/env bash
# Installation Script for DirectX 12 Atomic64 Compatibility Layer
# Updates both the target bottle and the CrossOver GPTK wine directory with full backup.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LAYER_DIR="$(dirname "$SCRIPT_DIR")"

# Locate source d3d12.dll
if [ -f "$LAYER_DIR/source/d3d12.dll" ]; then
    SOURCE_DLL="$LAYER_DIR/source/d3d12.dll"
elif [ -f "$LAYER_DIR/d3d12.dll" ]; then
    SOURCE_DLL="$LAYER_DIR/d3d12.dll"
elif [ -f "$SCRIPT_DIR/d3d12.dll" ]; then
    SOURCE_DLL="$SCRIPT_DIR/d3d12.dll"
else
    echo "Compiled d3d12.dll not found. Attempting to build from source..."
    "$SCRIPT_DIR/build_atomic64.sh"
    SOURCE_DLL="$LAYER_DIR/source/d3d12.dll"
fi

# Locate CrossOver installation
CX_DIR="/Applications/CrossOver.app/Contents/SharedSupport/CrossOver"
if [ ! -d "$CX_DIR" ] && [ -d "$HOME/Applications/CrossOver.app/Contents/SharedSupport/CrossOver" ]; then
    CX_DIR="$HOME/Applications/CrossOver.app/Contents/SharedSupport/CrossOver"
fi
CX_ENGINE_DLL="$CX_DIR/lib64/apple_gptk/wine/x86_64-windows/d3d12.dll"

# Detect bottles
BOTTLES_BASE="$HOME/Library/Application Support/CrossOver/Bottles"
BOTTLE_NAME="${1:-}"

if [ -z "$BOTTLE_NAME" ]; then
    if [ -d "$BOTTLES_BASE/Steam-2" ]; then
        BOTTLE_NAME="Steam-2"
    elif [ -d "$BOTTLES_BASE/Steam" ]; then
        BOTTLE_NAME="Steam"
    elif [ -d "$BOTTLES_BASE" ]; then
        FIRST_BOTTLE="$(ls -1 "$BOTTLES_BASE" 2>/dev/null | head -n 1 || true)"
        if [ -n "$FIRST_BOTTLE" ]; then
            BOTTLE_NAME="$FIRST_BOTTLE"
        fi
    fi
fi

if [ -z "$BOTTLE_NAME" ] || [ ! -d "$BOTTLES_BASE/$BOTTLE_NAME" ]; then
    echo "ERROR: Target bottle not found or not specified."
    echo "Available CrossOver bottles in $BOTTLES_BASE:"
    ls -1 "$BOTTLES_BASE" 2>/dev/null || echo "  (none found)"
    echo ""
    echo "Usage: $0 <Bottle_Name>"
    echo "Example: $0 Steam-2"
    exit 1
fi

BOTTLE_DIR="$BOTTLES_BASE/$BOTTLE_NAME"
BOTTLE_DLL="$BOTTLE_DIR/drive_c/windows/system32/d3d12.dll"

TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP_DIR="$BOTTLE_DIR/backup_atomic64_$TIMESTAMP"
mkdir -p "$BACKUP_DIR"

echo "=== Installing Atomic64 Compatibility Layer (Bottle: $BOTTLE_NAME, Timestamp: $TIMESTAMP) ==="

# 1. Back up and install to CrossOver GPTK engine directory
if [ -f "$CX_ENGINE_DLL" ]; then
    echo "[1/3] Backing up CrossOver engine d3d12.dll..."
    cp "$CX_ENGINE_DLL" "$BACKUP_DIR/cx_engine_d3d12.dll.bak"
    echo "  Original Engine SHA256: $(shasum -a 256 "$BACKUP_DIR/cx_engine_d3d12.dll.bak" | cut -d' ' -f1)"
    echo "  Deploying Atomic64 d3d12.dll to CrossOver engine..."
    cp "$SOURCE_DLL" "$CX_ENGINE_DLL"
    echo "  Deployed Engine SHA256: $(shasum -a 256 "$CX_ENGINE_DLL" | cut -d' ' -f1)"
else
    echo "[1/3] Skipping CrossOver engine (path not found: $CX_ENGINE_DLL)"
fi

# 2. Back up and install to target bottle system32
if [ -f "$BOTTLE_DLL" ]; then
    echo "[2/3] Backing up bottle system32 d3d12.dll..."
    cp "$BOTTLE_DLL" "$BACKUP_DIR/bottle_d3d12.dll.bak"
    echo "  Original Bottle SHA256: $(shasum -a 256 "$BACKUP_DIR/bottle_d3d12.dll.bak" | cut -d' ' -f1)"
    echo "  Deploying Atomic64 d3d12.dll to bottle system32..."
    cp "$SOURCE_DLL" "$BOTTLE_DLL"
    echo "  Deployed Bottle SHA256: $(shasum -a 256 "$BOTTLE_DLL" | cut -d' ' -f1)"
else
    echo "[2/3] Deploying Atomic64 d3d12.dll directly to bottle system32..."
    mkdir -p "$(dirname "$BOTTLE_DLL")"
    cp "$SOURCE_DLL" "$BOTTLE_DLL"
fi

# 3. Configure cxbottle.conf
CONF_FILE="$BOTTLE_DIR/cxbottle.conf"
if [ -f "$CONF_FILE" ]; then
    echo "[3/3] Configuring environment in cxbottle.conf..."
    cp "$CONF_FILE" "$BACKUP_DIR/cxbottle.conf.bak"
    if ! grep -q "\[EnvironmentVariables\]" "$CONF_FILE"; then
        echo -e "\n[EnvironmentVariables]" >> "$CONF_FILE"
    fi
    for KEY in "HB_ATOMIC64_OPTIONS11" "HB_ATOMIC64_OPTIONS9" "HB_ATOMIC64_EMULATE"; do
        if grep -q "\"$KEY\"" "$CONF_FILE"; then
            sed -i '' "s/\"$KEY\" = .*/\"$KEY\" = \"1\"/" "$CONF_FILE"
        else
            echo "\"$KEY\" = \"1\"" >> "$CONF_FILE"
        fi
    done
fi

echo -e "\n=== Installation Completed Successfully ==="
echo "Backup preserved at: $BACKUP_DIR"
echo "To rollback anytime, run: $SCRIPT_DIR/rollback_atomic64.sh $BOTTLE_NAME $BACKUP_DIR"
