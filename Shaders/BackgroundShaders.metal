#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

/// Returns a gently warped source position for SwiftUI's distortionEffect.
/// Ambient terms remain active in silence; audio only increases their scale.
[[ stitchable ]] float2 resonanceBackgroundDistortion(
    float2 position,
    float time,
    float amplitude,
    float energy,
    float bass,
    float mids,
    float treble
) {
    float2 field = position * 0.0052;
    float slowTime = time * 0.115;

    float broadX = sin((field.y * 1.55) + slowTime)
        + (0.42 * cos((field.x + field.y) * 0.83 - (slowTime * 0.71)));
    float broadY = cos((field.x * 1.38) - (slowTime * 0.91))
        + (0.38 * sin((field.x - field.y) * 1.07 + (slowTime * 0.63)));

    float2 relativeCenter = field - float2(0.92, 1.63);
    float centerWave = sin((length(relativeCenter) * 3.0) - (time * 0.22));
    float2 centerDirection = relativeCenter / max(length(relativeCenter), 0.15);

    float shimmer = sin(
        (field.x * 7.3) + (field.y * 5.9) + (time * 1.6)
    ) * treble;
    float2 displacement = float2(broadX, broadY) * (0.52 + (energy * 0.48));
    displacement += centerDirection * centerWave * bass * 0.26;
    displacement += float2(broadY, -broadX) * mids * 0.18;
    displacement += float2(shimmer, -shimmer * 0.7) * 0.055;

    return position + (displacement * amplitude);
}
