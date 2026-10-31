#!/usr/bin/env bash
# Build Script for DirectX 12 64-bit Atomic Compatibility Layer on Apple Silicon
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LAYER_DIR="$(dirname "$SCRIPT_DIR")"
SOURCE_DIR="$LAYER_DIR/source"
TESTS_DIR="$LAYER_DIR/tests"

echo "=== Building DirectX 12 Atomic64 Compatibility Layer ==="
if ! command -v x86_64-w64-mingw32-gcc >/dev/null 2>&1; then
    echo "ERROR: x86_64-w64-mingw32-gcc not found in PATH."
    exit 1
fi

cd "$SOURCE_DIR"
echo "[1/3] Compiling d3d12.dll (x86_64-w64-mingw32-gcc -shared -O2)..."
x86_64-w64-mingw32-gcc -shared -O2 -Wall -static-libgcc -o d3d12.dll d3d12_atomic64.c d3d12.def

echo "[2/3] Stamping Wine builtin DLL marker..."
python3 mark-builtin.py d3d12.dll

echo "[3/3] Compiling DirectX 12 test harness..."
cd "$TESTS_DIR"
x86_64-w64-mingw32-gcc -O2 -Wall d3d12_atomic64_test.c -o d3d12_atomic64_test.exe

echo "=== Build Complete ==="
echo "Artifacts produced:"
ls -lh "$SOURCE_DIR/d3d12.dll" "$TESTS_DIR/d3d12_atomic64_test.exe"
