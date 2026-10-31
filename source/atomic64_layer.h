#ifndef ATOMIC64_LAYER_H
#define ATOMIC64_LAYER_H

#include <windows.h>
#include <d3d12.h>
#include <stdio.h>
#include <stdint.h>
#include <stdbool.h>

// Environment controls
static int g_atomic64_options11_mode = 1;   // 1 = report AtomicInt64OnDescriptorHeapResource = TRUE
static int g_atomic64_options9_mode  = 1;   // 1 = report Typed & GroupShared 64-bit atomics = TRUE
static int g_atomic64_emulate        = 1;   // 1 = enable DXIL bytecode inspection & safety fallback
static int g_atomic64_debug          = 0;   // 1 = verbose debug logging

static inline void atomic64_init_env(void) {
    char buf[16];
    if (GetEnvironmentVariableA("HB_ATOMIC64_OPTIONS11", buf, sizeof(buf)) > 0) {
        g_atomic64_options11_mode = (buf[0] != '0');
    }
    if (GetEnvironmentVariableA("HB_ATOMIC64_OPTIONS9", buf, sizeof(buf)) > 0) {
        g_atomic64_options9_mode = (buf[0] != '0');
    }
    if (GetEnvironmentVariableA("HB_ATOMIC64_EMULATE", buf, sizeof(buf)) > 0) {
        g_atomic64_emulate = (buf[0] != '0');
    }
    if (GetEnvironmentVariableA("HB_ATOMIC64_DEBUG", buf, sizeof(buf)) > 0) {
        g_atomic64_debug = (buf[0] != '0');
    }
}

// Intercept CheckFeatureSupport for Options11 & Options9
static inline bool atomic64_check_feature_support(D3D12_FEATURE feature, void *data, UINT size, HRESULT *out_hr) {
    // Feature 40: D3D12_FEATURE_D3D12_OPTIONS11
    if ((int)feature == 40 && data && size >= sizeof(D3D12_FEATURE_DATA_D3D12_OPTIONS11)) {
        D3D12_FEATURE_DATA_D3D12_OPTIONS11 *opt11 = (D3D12_FEATURE_DATA_D3D12_OPTIONS11 *)data;
        if (g_atomic64_options11_mode) {
            opt11->AtomicInt64OnDescriptorHeapResourceSupported = TRUE;
            *out_hr = S_OK;
            return true; // handled
        }
    }
    // Feature 37: D3D12_FEATURE_D3D12_OPTIONS9
    else if ((int)feature == 37 && data && size >= sizeof(D3D12_FEATURE_DATA_D3D12_OPTIONS9)) {
        D3D12_FEATURE_DATA_D3D12_OPTIONS9 *opt9 = (D3D12_FEATURE_DATA_D3D12_OPTIONS9 *)data;
        if (g_atomic64_options9_mode) {
            opt9->AtomicInt64OnTypedResourceSupported = TRUE;
            opt9->AtomicInt64OnGroupSharedSupported = TRUE;
            *out_hr = S_OK;
            return true; // handled
        }
    }
    return false; // pass through to real implementation
}

// Simple DXBC container inspector for 64-bit atomic opcodes
typedef struct {
    uint32_t magic;      // 'DXBC' (0x43425844)
    uint8_t  digest[16];
    uint32_t major_version;
    uint32_t container_size;
    uint32_t part_count;
} DXBCHeader;

static inline bool dxbc_has_atomic64(const void *bytecode, size_t length) {
    if (!bytecode || length < sizeof(DXBCHeader)) return false;
    const uint8_t *bytes = (const uint8_t *)bytecode;
    if (*(const uint32_t *)bytes != 0x43425844) return false; // not 'DXBC'

    const DXBCHeader *hdr = (const DXBCHeader *)bytes;
    if (hdr->container_size > length || hdr->part_count > 64) return false;

    const uint32_t *part_offsets = (const uint32_t *)(bytes + sizeof(DXBCHeader));
    for (uint32_t i = 0; i < hdr->part_count; i++) {
        uint32_t off = part_offsets[i];
        if (off + 8 > length) break;
        uint32_t fourcc = *(const uint32_t *)(bytes + off);
        uint32_t part_size = *(const uint32_t *)(bytes + off + 4);
        
        // 'DXIL' part (0x4C495844)
        if (fourcc == 0x4C495844 && off + 8 + part_size <= length) {
            const uint8_t *dxil_data = bytes + off + 8;
            // Scan for atomic substrings or LLVM bitcode records
            // In DXIL bitcode: "dx.op.atomicBinOp" or "dx.op.atomicCompareExchange"
            for (size_t j = 0; j + 18 <= part_size; j++) {
                if (memcmp(dxil_data + j, "dx.op.atomicBinOp", 17) == 0 ||
                    memcmp(dxil_data + j, "dx.op.atomicCompareExchange", 27) == 0) {
                    return true;
                }
            }
        }
    }
    return false;
}

#endif // ATOMIC64_LAYER_H
