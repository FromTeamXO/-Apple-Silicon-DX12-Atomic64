# Apple Silicon DirectX 12 Compatibility Layer: 64-bit Atomics & Modern RE Engine Support

An experimental DirectX 12 translation-layer extension and compatibility patch designed to enable unsupported modern Windows DirectX 12 games (specifically Capcom's RE Engine titles including **Resident Evil Requiem / Resident Evil 9** and **PRAGMATA**) to run on Apple Silicon M1 Max GPUs through CrossOver and D3DMetal.

---

## 🤖 1. Autonomous AI Agent Installation (Claude, Antigravity, Cursor)

If you are using an AI coding assistant (such as **Claude Code**, **Antigravity**, **Cursor Agent**, or **Codex**), copy and paste the prompt below. The agent will inspect your Mac, deploy the compatibility layer into your active CrossOver bottle, run verification benchmarks, and confirm mathematically correct execution automatically:

````markdown
You are acting as an expert graphics systems engineer. Your task is to install, configure, and verify the Apple Silicon DirectX 12 Atomic64 Compatibility Layer onto this Mac to enable unsupported DirectX 12 games (such as Capcom's RE Engine titles like Resident Evil 9 / Requiem and PRAGMATA) in CrossOver.

Target Repository: https://github.com/wn6nmtk6r7-wq/Apple-Silicon-DX12-Atomic64.git

Please execute the following steps autonomously:

### 1. Pre-flight Environment Inspection
- Check the Apple Silicon GPU family and macOS version (`uname -m`, `sw_vers`).
- Locate the CrossOver installation (`/Applications/CrossOver.app` or `~/Applications/CrossOver.app`).
- List existing bottles in `~/Library/Application Support/CrossOver/Bottles/`. If the user has a specific bottle (e.g., `Steam`, `Steam-2`), select it; otherwise, default to the most relevant gaming bottle or ask for clarification if ambiguous.

### 2. Fetch and Prepare the Compatibility Layer
- Clone the repository to a temporary workspace:
  ```bash
  git clone https://github.com/wn6nmtk6r7-wq/Apple-Silicon-DX12-Atomic64.git /tmp/dx12-atomic64
  cd /tmp/dx12-atomic64
  ```
- If the files are inside a nested subdirectory (`Apple-Silicon-DirectX-12-Atomic64-Compatibility-Layer-For-M1-M2/`), navigate into it or move the contents to the root of the workspace.
- Ensure all scripts and test binaries have executable permissions:
  ```bash
  chmod +x install.sh run_benchmarks.sh rollback.sh scripts/*.sh tests/metal_atomic64_benchmark tests/d3d12_atomic64_test.exe 2>/dev/null || true
  ```

### 3. Deploy to CrossOver & Target Bottle
- Execute the installation script for the chosen bottle:
  ```bash
  ./install.sh "<BOTTLE_NAME>"
  ```
- Confirm that the script:
  1. Creates a timestamped backup in `~/Library/Application Support/CrossOver/Bottles/<BOTTLE_NAME>/backup_atomic64_<timestamp>/`.
  2. Deploys the Atomic64 `d3d12.dll` to CrossOver's GPTK Wine engine and the bottle's `drive_c/windows/system32/`.
  3. Injects `"HB_ATOMIC64_OPTIONS11" = "1"`, `"HB_ATOMIC64_OPTIONS9" = "1"`, and `"HB_ATOMIC64_EMULATE" = "1"` into `cxbottle.conf`.

### 4. Verification & Validation Benchmarks
- Run the benchmark and verification suite:
  ```bash
  ./run_benchmarks.sh "<BOTTLE_NAME>"
  ```
- Validate that:
  - Step 1 (Native Metal Compute): Both Benchmark 1 (Split-32 Add) and Benchmark 2 (2-Phase Visibility Packing) output `Correctness: PASSED`.
  - Step 2 (DirectX 12 API Test): Returns `OPTIONS11: AtomicInt64OnDescriptorHeapResourceSupported = 1`, `Highest Shader Model: 0x66`, and `DescriptorHeapResourceBinding: PASS`.

### 5. Final Report
Provide a concise summary containing:
- Target Bottle Name and installed DLL paths.
- Benchmark results (throughput and pass status).
- Exact path to the automatic backup and the one-line rollback command to restore baseline settings at any time.
````

---

## ⚡ 2. Manual Quick Start

### Installation
Clone the repository and deploy directly into your CrossOver bottle (defaults to `Steam-2` or auto-detects active bottles):
```bash
git clone https://github.com/wn6nmtk6r7-wq/Apple-Silicon-DX12-Atomic64.git
cd Apple-Silicon-DX12-Atomic64
./install.sh
```
Or specify a bottle by name:
```bash
./install.sh "Your-Bottle-Name"
```

### Verification & Benchmarks
Run both the native Metal shader benchmarks and the DirectX 12 API test harness:
```bash
./run_benchmarks.sh
```

### Rollback
Restore your CrossOver installation and bottle back to their pristine baseline anytime:
```bash
./rollback.sh
```

---

## 🔬 3. Executive Summary & Core Findings

### Missing Capability
Modern DirectX 12 engines unconditionally query `D3D12_FEATURE_DATA_D3D12_OPTIONS11` (`0x28`) for:
```c
AtomicInt64OnDescriptorHeapResourceSupported = 1
```

* **Hardware Level (M1 Max / Apple7 GPU)**: Apple Silicon M1 Max (`AGX G13X`) does not provide hardware ALUs for 64-bit atomic arithmetic on descriptor heap resources. The Metal compiler rejects 64-bit integer atomics (`atomic_fetch_add_explicit`, `atomic_min_explicit`) on Apple7 target families with `[FAIL-PSO] atomic_min_explicit: Unsupported i64 atomic operation for given target`.
* **D3DMetal Behavior**: At address `0x2e516`, D3DMetal reads a global family check initialized at `0x3c2cd` (`supportsFamily:1008` / Apple8). Because M1 Max reports Apple7 (`1007`), D3DMetal unconditionally sets `AtomicInt64OnDescriptorHeapResourceSupported = 0`.
* **Game Reaction**: When RE Engine receives `0`, it displays a fatal Win32 error dialog:
  > *"DirectX 12 feature level requirements not met. AtomicInt64OnDescriptorHeapResourceSupported is not supported."*

### Compatibility Approach & Emulation Strategy
Unlike AMD Vega (GFX9) which physically features 64-bit atomic ALU instructions (`BUFFER_ATOMIC_*_X2`, `DS_ADD_RTN_U64`) and only failed due to WDDM 3.0 descriptor heap certification halts, Apple Silicon requires active shader execution fallbacks:
1. **Lockless Split-32-bit Carry-Accumulation**: High-throughput monotonic counter emulation (allocators, SVT feedback). Throughput: **829.12M ops/sec** (0 lost updates).
2. **2-Phase Visibility Buffer 64-bit Depth-ID Packing**: Emulates `InterlockedMin64` on packed `{Depth:32, PrimitiveID:32}` using native 32-bit depth minimization followed by matched primitive-ID resolution. Throughput: **2,482.49M frags/sec** with 0% depth tearing on 4K buffers.

---

## 📁 4. Directory Structure

```
.
├── README.md                                   # Project documentation & agent prompts
├── LICENSE                                     # MIT License
├── install.sh                                  # Quick installer (root wrapper)
├── run_benchmarks.sh                           # Quick benchmark runner (root wrapper)
├── rollback.sh                                 # Quick rollback script (root wrapper)
├── docs/
│   ├── 01_FEASIBILITY_REPORT.md                 # Technical feasibility & architectural analysis
│   ├── 02_MISSING_GPU_CAPABILITY_ANALYSIS.md   # D3DMetal disassembly & Apple7/8/9 feature matrix
│   ├── 03_AMD_VEGA_COMPATIBILITY_INVESTIGATION.md # GFX9 ISA vs Apple7 execution units
│   └── 04_GAME_COMPATIBILITY_RE9_PRAGMATA.md   # RE Engine & PRAGMATA startup analysis
├── scripts/
│   ├── build_atomic64.sh                       # Automated MinGW64 build script
│   ├── install_atomic64.sh                     # CrossOver bottle deployment with auto-backup
│   ├── rollback_atomic64.sh                    # Instant automated restoration script
│   └── run_benchmarks.sh                       # End-to-end benchmark & DX12 verification runner
├── source/
│   ├── atomic64_layer.h                        # Core emulation structures & state
│   ├── binding_capture.h                       # Argument buffer & descriptor binding capture
│   ├── d3d12.def                               # Export ordinals (preserving Ordinal 100/101)
│   ├── d3d12.dll                               # Pre-built Wine builtin DLL
│   ├── d3d12_atomic64.c                        # Main proxy interception shim
│   ├── descriptor_capture.h                    # Shader-visible descriptor heap management
│   ├── input_offsets.h                         # Packed vertex input layout compatibility
│   ├── mark-builtin.py                         # Wine builtin DLL header stamper
│   └── upload_capture.h                        # GPU upload buffer tracking
└── tests/
    ├── d3d12_atomic64_test.c                   # Standalone C DX12 test harness
    ├── d3d12_atomic64_test.exe                 # Compiled DX12 test executable
    ├── metal_atomic64_benchmark.m              # Native Metal compute kernel benchmark
    └── metal_atomic64_benchmark                # Compiled ARM64 Metal benchmark binary
```

---

## 📊 5. Verified Benchmark Results (Apple M1 Max, 32 GPU Cores)

### Benchmark 1: Lockless Split-32-bit Atomic Add
* **Threads Dispatched**: 16,777,216
* **Execution Time**: 20.24 ms
* **Throughput**: **829.12 Million Atomics/sec**
* **Correctness**: **PASSED** (100.0% mathematical accuracy, 0 lost updates)

### Benchmark 2: 2-Phase Visibility Buffer 64-bit Depth-ID Packing
* **Fragments Processed**: 8,388,608 (Target: 4K Framebuffer 3840×2160)
* **Execution Time**: 3.38 ms
* **Throughput**: **2,482.49 Million Fragments/sec**
* **Correctness**: **PASSED** (Zero depth tearing, 100% sub-pixel resolution)

### Benchmark 3: DirectX 12 Capability & Descriptor Heap Verification (Wine / CrossOver)
```text
[DX12-TEST] Loaded D3D12 module: C:\windows\system32\d3d12.dll
[DX12-TEST] ID3D12Device created successfully.
[DX12-TEST] Highest Shader Model: 0x66 (SM 6.6)
[DX12-TEST] OPTIONS11: AtomicInt64OnDescriptorHeapResourceSupported = 1
[DX12-TEST] OPTIONS9: AtomicInt64OnTypedResource = 1, AtomicInt64OnGroupShared = 1
[DX12-TEST] OPTIONS: ResourceBindingTier = 3 (Tier 3 = Bindless)
[DX12-TEST] Shader-Visible CBV_SRV_UAV Descriptor Heap created successfully (128 descriptors).
[DX12-TEST] Raw Unordered Access View (UAV) bound to Descriptor Heap slot 0.
[DX12-TEST] Command list executed and GPU fence synchronized.
[DX12-TEST] DirectX 12 Test Summary: ALL PASS
```

---

## 🛠️ 6. Building from Source
Prerequisites: `x86_64-w64-mingw32-gcc`, Python 3.
```bash
./scripts/build_atomic64.sh
```
