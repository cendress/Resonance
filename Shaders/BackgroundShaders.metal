#include <metal_stdlib>
using namespace metal;

// Placeholder only. The final background shader will be implemented later.
kernel void resonanceBackgroundPlaceholder(
    device float *output [[buffer(0)]],
    uint index [[thread_position_in_grid]]
) {
    output[index] = 0.0;
}
