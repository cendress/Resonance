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
    float treble,
    float beat
) {
    float2 field = position * 0.0042;
    float verySlowTime = time * 0.075;
    float slowTime = time * 0.17;
    float foldingTime = time * 0.31;

    // The first field carries the major color masses in two directions. The
    // second samples that already-warped domain so bends become folds rather
    // than a uniform sliding wave.
    float2 broadFlow = float2(
        sin((field.y * 1.72) + verySlowTime)
            + (0.46 * cos(((field.x + field.y) * 1.08) - (slowTime * 0.61))),
        cos((field.x * 1.48) - (verySlowTime * 0.87))
            + (0.43 * sin(((field.x - field.y) * 1.21) + (slowTime * 0.72)))
    );
    float2 foldedField = field + (broadFlow * 0.20);
    float2 crossFlow = float2(
        cos((foldedField.y * 2.35) - (foldingTime * 0.83))
            + (0.36 * sin((foldedField.x * 1.86) + slowTime)),
        sin((foldedField.x * 2.12) + foldingTime)
            - (0.34 * cos((foldedField.y * 1.74) - (slowTime * 0.91)))
    );
    float curl = sin(
        (foldedField.x * 3.15)
            + (foldedField.y * 2.64)
            + foldingTime
    );

    // Bass moves a broad pressure center around the composition. Beat adds a
    // short pressure pulse without changing any of the flow rates.
    float2 pressureCenter = float2(
        0.84 + (sin((time * 0.13) + 0.6) * 0.54),
        1.44 + (cos((time * 0.11) + 1.7) * 0.72)
    );
    float2 relativeCenter = field - pressureCenter;
    float centerDistance = max(length(relativeCenter), 0.16);
    float pressureWave = sin((centerDistance * 3.25) - (time * 0.24));
    float2 pressureDirection = relativeCenter / centerDistance;

    float shimmer = sin(
        (foldedField.x * 8.1)
            + (foldedField.y * 6.7)
            + (time * 1.55)
    ) * treble;
    float2 displacement = broadFlow * (0.48 + (energy * 0.40));
    displacement += float2(crossFlow.y, -crossFlow.x)
        * (0.16 + (mids * 0.24) + (energy * 0.10));
    displacement += float2(curl, -curl * 0.72) * (0.075 + (mids * 0.055));
    displacement += pressureDirection
        * pressureWave
        * ((bass * 0.34) + (beat * 0.14));
    displacement += float2(shimmer, -shimmer * 0.68) * 0.052;

    return position + (displacement * amplitude);
}
