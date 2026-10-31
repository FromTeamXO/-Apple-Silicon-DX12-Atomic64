#!/usr/bin/env bash
# Benchmark Runner for DirectX 12 Atomic64 Compatibility on Apple Silicon
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LAYER_DIR="$(dirname "$SCRIPT_DIR")"
TESTS_DIR="$LAYER_DIR/tests"
BOTTLE_NAME="${1:-Steam-2}"

echo "=================================================================="
echo "Running Apple Silicon M1 Max DirectX 12 & Metal Atomic Benchmarks"
echo "=================================================================="

echo -e "\n--- Step 1: Metal Native & Emulated Shader Benchmarks ---"
if [ ! -f "$TESTS_DIR/metal_atomic64_benchmark" ]; then
    echo "Compiling native Metal benchmark..."
    clang -framework Metal -framework Foundation "$TESTS_DIR/metal_atomic64_benchmark.m" -o "$TESTS_DIR/metal_atomic64_benchmark"
fi
chmod +x "$TESTS_DIR/metal_atomic64_benchmark"
"$TESTS_DIR/metal_atomic64_benchmark"

echo -e "\n--- Step 2: DirectX 12 API Capability & Descriptor Heap Test Harness ---"
WINE_BIN="/Applications/CrossOver.app/Contents/SharedSupport/CrossOver/bin/wine"
if [ ! -x "$WINE_BIN" ] && [ -x "$HOME/Applications/CrossOver.app/Contents/SharedSupport/CrossOver/bin/wine" ]; then
    WINE_BIN="$HOME/Applications/CrossOver.app/Contents/SharedSupport/CrossOver/bin/wine"
fi

if [ -x "$WINE_BIN" ]; then
    "$WINE_BIN" --bottle "$BOTTLE_NAME" "$TESTS_DIR/d3d12_atomic64_test.exe"
else
    echo "CrossOver wine not found at $WINE_BIN — skipping Step 2 in native macOS environment."
fi

echo -e "\n=================================================================="
echo "Benchmarks Completed Successfully."
echo "=================================================================="
