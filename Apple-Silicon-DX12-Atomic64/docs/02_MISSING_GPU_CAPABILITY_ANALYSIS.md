# Detailed Missing GPU Capability Analysis
## Apple Silicon M1 Max vs. DirectX 12 Feature Options

---

### 1. DirectX 12 Capability Matrix

The table below contrasts the DirectX 12 capability requirements against the Apple M1 Max GPU running through CrossOver 26.3 and D3DMetal (GPTK runtime):

| Feature Structure | Field / Capability | Required by Game | Native M1 Max Hardware | D3DMetal Report | Status / Root Cause |
|---|---|---|---|---|---|
| **D3D12_OPTIONS11** | `AtomicInt64OnDescriptorHeapResourceSupported` | **TRUE** (Fatal check in RE9 / Pragmata) | **FALSE** (AGX G13X has no i64 atomics) | **FALSE** (`0x0`) | **Hard Blocker** (Checked in D3DMetal via `supportsFamily: Apple8`) |
| **D3D12_OPTIONS9** | `AtomicInt64OnTypedResourceSupported` | Recommended | **FALSE** | **TRUE** (`0x1`) | **Spoofed by D3DMetal** (Hardcoded in Options9 constant table) |
| **D3D12_OPTIONS9** | `AtomicInt64OnGroupSharedSupported` | Recommended | **FALSE** | **TRUE** (`0x1`) | **Spoofed by D3DMetal** (Hardcoded in Options9 constant table) |
| **D3D12_OPTIONS9** | `MeshShaderPipelineStatsSupported` | Optional | **TRUE** | **TRUE** (`0x1`) | Supported |
| **D3D12_OPTIONS9** | `WaveMMATier` | Optional | `D3D12_WAVE_MMA_TIER_1` | Tier 1 | Supported (Simdgroup matrix) |
| **SHADER_MODEL** | Highest Shader Model | SM 6.6 (`0x66`) | SM 6.6 | SM 6.6 | Supported on macOS 14.4+ with Metal 3 |
| **D3D12_OPTIONS4** | `Native16BitShaderOpsSupported` | Optional | **TRUE** | **TRUE** (`0x1`) | Supported (FP16 half-precision) |
| **D3D12_OPTIONS** | `ResourceBindingTier` | Tier 3 (Bindless) | Tier 3 | Tier 3 | Supported via Metal Argument Buffers Tier 2 |
| **D3D12_OPTIONS** | `TiledResourcesTier` | Tier 1/2 | Tier 1/2 | Tier 1 | Supported via Metal Sparse Textures |

---

### 2. Forensic Disassembly of D3DMetal Capability Handling

Analysis of `/Applications/CrossOver.app/Contents/SharedSupport/CrossOver/lib64/apple_gptk/external/D3DMetal.framework/Versions/A/D3DMetal` confirms the exact mechanisms governing capability reporting.

#### 2.1 Initialization of `AtomicInt64OnDescriptorHeapResourceSupported`
At library initialization (subroutine `D3D12Device::Initialize()`):
```assembly
000000000003c2cd  movq   0x48(%r14), %rdi               ; rdi = [MTLDevice pointer]
000000000003c2d1  movl   $0x3f0, %edx                   ; edx = 0x3f0 = 1008 = MTLGPUFamilyApple8
000000000003c2d6  movq   %rbx, %rsi                     ; rsi = @selector(supportsFamily:)
000000000003c2d9  callq  *0x32a031(%rip)                ; _objc_msgSend
000000000003c2df  testb  %al, %al                       ; Test result (1 on M2+, 0 on M1)
000000000003c2e1  je     0x3c2ef                        ; If 0, bypass setting to 1
000000000003c2e3  movl   $0xe04, %edi                   ; edi = 0xe04 = macOS 14.4
000000000003c2e8  callq  IsAtLeastOSVersions
000000000003c2ed  movl   %eax, %ebp
000000000003c2ef  movb   %bpl, __ZN11D3D12Device44AtomicInt64OnDescriptorHeapResourceSupportedE(%rip)
```
* **Address**: `0x0003c2ef` writes into global variable `0x003ac19f`.
* **Hardware Threshold**: Requires `MTLGPUFamilyApple8` (Apple M2 generation and above) AND macOS 14.4+.
* **M1 Max Execution**: Since Apple M1 Max belongs strictly to `MTLGPUFamilyApple7` (1007), `[device supportsFamily:1008]` returns `0`, causing the global variable to remain `0`.

#### 2.2 Response in `CheckFeatureSupport`
At `__ZN11D3D12Device19CheckFeatureSupportE13D3D12_FEATUREPvj`:
```assembly
; Jump table dispatch for Feature 40 (0x28 = D3D12_FEATURE_D3D12_OPTIONS11)
000000000002e516  cmpl   $0x4, %r9d                     ; Verify size >= sizeof(BOOL)
000000000002e51a  jne    0x2e99d                        ; If invalid size, return E_INVALIDARG
000000000002e520  movzbl __ZN11D3D12Device44AtomicInt64OnDescriptorHeapResourceSupportedE(%rip), %eax
000000000002e527  movl   %eax, (%r14)                   ; Write BOOL into pFeatureSupportData
000000000002e52a  jmp    0x2e99b                        ; Return S_OK
```

#### 2.3 Options9 Constant Response
For Feature 37 (`0x25` = `D3D12_FEATURE_D3D12_OPTIONS9`):
```assembly
000000000002e8fc  cmpl   $0x18, %r9d                    ; sizeof(OPTIONS9) == 24 bytes
000000000002e900  jne    0x2e99d
000000000002e906  movaps 0x21d863(%rip), %xmm0          ; Load constant table from 0x24c170
000000000002e91c  movups %xmm0, (%r14)
000000000002e920  movq   $0x0, 0x10(%r14)
000000000002e928  jmp    0x2e99b
```
Inspecting file offset `0x24c170` reveals the 24-byte payload:
`01 00 00 00  01 00 00 00  01 00 00 00  01 00 00 00  00 00 00 00  01 00 00 00`
Corresponding to:
* `MeshShaderPipelineStatsSupported = 1`
* `MeshShaderSupportsFullRangeRenderTargetArrayIndex = 1`
* `AtomicInt64OnTypedResourceSupported = 1` (Statically reported as TRUE!)
* `AtomicInt64OnGroupSharedSupported = 1` (Statically reported as TRUE!)
* `DerivativesInMeshAndAmplificationShadersSupported = 0`
* `WaveMMATier = 1`

D3DMetal already reports `AtomicInt64OnTypedResourceSupported` and `AtomicInt64OnGroupSharedSupported` as `TRUE` unconditionally; **only `AtomicInt64OnDescriptorHeapResourceSupported` is restricted on M1 Max**.

---

### 3. Four-Tier Incompatibility Breakdown

To design a clean compatibility architecture, we distinguish between the four levels:

#### Tier 1: Hardware Execution Level (Apple7 AGX G13X)
* **Status**: Missing hardware instructions.
* **Details**: The M1 Max GPU has thirty-two 32-wide SIMD execution units. Hardware atomic memory operations are managed by the L2 Cache and Texture Processing Clusters (TPCs). While the L2 cache handles 32-bit atomic add, sub, exchange, min, max, and bitwise ops (`atom.*.u32`), it does not have a 64-bit atomic RMW arithmetic data path.

#### Tier 2: Metal Shading Language & Compiler Level
* **Status**: Missing backend code-generation lowering.
* **Details**: MSL defines `atomic_ulong` in header `<metal_atomic>` behind macro `__HAVE_ATOMIC_ULONG__`. However, functions such as `atomic_fetch_add_explicit` and `atomic_compare_exchange_*` explicitly gate on `_valid_fetch_add_sub_type`, which is restricted to 32-bit types on Apple7. Attempting to force an atomic 64-bit operation produces a compile-time or pipeline-creation failure:
  `Unsupported i64 atomic operation for given target.`

#### Tier 3: D3DMetal Translation Level
* **Status**: Hard hardware check (`MTLGPUFamilyApple8`).
* **Details**: D3DMetal intentionally disables `AtomicInt64OnDescriptorHeapResourceSupported` on M1 Max to avoid feeding 64-bit atomic instructions into a Metal compiler that cannot compile them.

#### Tier 4: Game Application Level (Capcom RE Engine)
* **Status**: Strict startup requirement without fallback.
* **Details**: The RE Engine startup orchestrator (`re9.exe` / `pragmata.exe`) initializes DirectX 12, queries `ID3D12Device::CheckFeatureSupport(D3D12_FEATURE_D3D12_OPTIONS11, &opt11, 4)`, and if `opt11.AtomicInt64OnDescriptorHeapResourceSupported == 0`, immediately spawns a Win32 message box and calls `ExitProcess(1)` before any window or renderer surface is created.

---

### 4. Technical Conclusion

A superficial fix (such as patching D3DMetal to unconditionally return `1` for Options11) will allow the engine to bypass the startup dialog, but will crash the renderer during shader compilation unless paired with an **emulation or alternative shader path**. 

Therefore, our compatibility layer must operate as an **interception proxy** that combines:
1. Capability reporting override (`AtomicInt64OnDescriptorHeapResourceSupported = 1`).
2. DXIL shader inspection to intercept compute pipelines requesting 64-bit atomics.
3. Lowering of 64-bit atomic operations to verifiable 32-bit split primitives or visibility buffer passes.
