// Greenholm's water with waves and glints moving across it (FR-GREENHOLM-070,
// ADR-0038). The water keeps the colour and the roughness its material was made
// with. A dozen waves of falling size, each at its own speed, tilt its normal, so
// that the sun lights the slopes facing it and the gloss catches it on them; and
// where the waves run high together the colour is lifted towards white, a pale
// crest. Slow noise bends the crests and lets the waves rise and fall from place to
// place, so that they do not form a grid.
//
// The waves are laid out in world metres, not in the mesh's own space, so that the
// bands along the shore and the slabs beyond them ripple as one surface, with no
// seam where two meet.
//
// The ripple comes from the material, in the one four-component value a material
// carries: x the longest wavelength in metres, y the waves' speed as a share of the
// speed deep water carries a wave of their length, z how far a
// crest lifts the colour towards white, 0 to 1, w the waves' steepness as rise over
// run. The normal is worked out in the world and handed over in the tangent space of
// the fragment's geometry, which every water mesh carries. The contract is the SDK's own
// (RealityKitSurfaceShader.h, iOS 27.0 SDK), as for the hole shader beside the
// modules (SeeThroughHole.metal).
//
// file implements: FR-GREENHOLM-070, FR-MAP-280
#include <RealityKit/RealityKit.h>

using namespace metal;

/// The waves, as ocean shaders build them (GPU Gems 1, ch. 1; Tessendorf, "Simulating
/// Ocean Water"): many, each shorter and lower than the one before, so that the water
/// has waves of every size and not one size repeated; each running at the speed deep
/// water carries a wave of its length, ω = √(g k), so that long waves overtake short
/// ones and the pattern never holds still; each in its own direction within a spread
/// round the wind; and each shaped exp(sin − 1), a narrow crest over a wide trough.
///
/// What is the same for every point of the water is worked out once, here, and not
/// again for each: the shader runs over most of the screen, and on the phone it was a
/// quarter of the frame's GPU time while it did (ADR-0045). Each wave's direction,
/// from the wind (0.8, 0.6) turned by up to 1.05 radians either side, and its phase
/// at the start, both fixed by its number, fract(sin(n · 12.9898) · 43758.5453) for n
/// and n + ½; how many times shorter than the longest it is, 1.18 to the power of its
/// number, and so how many times faster it turns, the square root of that, since deep
/// water turns a wave at ω = √(g k); and how high it is, 0.82 to the power of its
/// number.
constant int kWaves = 12;
constant float kGravity = 9.81;
constant float2 kDirection[kWaves] = {
    float2(0.918511, -0.395396), float2(0.041733, 0.999129), float2(0.959284, -0.282444),
    float2(0.720850, 0.693091), float2(0.929278, 0.369380), float2(0.854708, 0.519109),
    float2(0.615100, 0.788449), float2(0.998273, -0.058747), float2(0.959764, 0.280806),
    float2(0.747363, 0.664416), float2(-0.062839, 0.998024), float2(0.250113, 0.968217),
};
constant float kStart[kWaves] = {
    1.712756, 4.150483, 2.834551, 0.981825, 1.612035, 0.213887,
    1.405638, 5.715645, 2.007865, 0.625641, 5.134091, 6.189084,
};
constant float kShorterBy[kWaves] = {
    1.000000, 1.180000, 1.392400, 1.643032, 1.938778, 2.287758,
    2.699554, 3.185474, 3.758859, 4.435454, 5.233836, 6.175926,
};
constant float kFasterBy[kWaves] = {
    1.000000, 1.086278, 1.180000, 1.281808, 1.392400, 1.512534,
    1.643032, 1.784790, 1.938778, 2.106052, 2.287758, 2.485141,
};
constant float kWeight[kWaves] = {
    1.000000, 0.820000, 0.672400, 0.551368, 0.452122, 0.370740,
    0.304007, 0.249285, 0.204414, 0.167620, 0.137448, 0.112707,
};
/// The weights' sum and the root of the sum of their squares.
constant float kWeights = 5.042111;
constant float kSpreadOfWeights = 1.739664;
/// Slow noise bends the crests and lets the waves rise and fall from place to place,
/// so that no line of them runs straight across the water: how many of the longest
/// wavelengths one lump of it spans, how far it moves the waves, in the same
/// wavelengths, how low it lets them fall, as a share of their full height, and how
/// fast it drifts, in lumps of it a second.
constant float kBendSpan = 3.1;
constant float kBend = 0.3;
constant float kHeightSpan = 5.3;
constant float kLowest = 0.35;
constant float kDrift = 0.05;
/// One wave exp(sin x − 1) over a whole turn: its mean height, e⁻¹·I₀(1), its standard
/// deviation, √(e⁻²·I₀(2) − mean²), and the root mean square of its slope along its
/// direction per unit of k·a, √(e⁻²·I₁(2)/2). Waves in random phases add as the root
/// of the sum of their squares, not as the sum; these turn the sum back into a height
/// in standard deviations and a slope of the configured steepness.
constant float kMeanShape = 0.466;
constant float kShapeSpread = 0.302;
constant float kSlopeSpread = 0.328;
/// How many standard deviations above the mean a crest begins, and where it is full.
constant float kGlintFrom = 1.3;
constant float kGlintFull = 2.3;

/// Value noise: -1 to 1, smooth between the whole points of the plane. Each whole
/// point's value is hashed by multiplying and folding alone, with no sine to pay for
/// at every corner (Hoskins, "Hash without Sine").
static float noise(float2 p)
{
    float2 whole = floor(p);
    float2 part = p - whole;
    float2 ease = part * part * (3.0 - 2.0 * part);
    auto corner = [&](float2 offset) {
        float3 q = fract(float3((whole + offset).xyx) * 0.1031);
        q += dot(q, q.yzx + 33.33);
        return fract((q.x + q.y) * q.z) * 2.0 - 1.0;
    };
    return mix(mix(corner(float2(0, 0)), corner(float2(1, 0)), ease.x),
               mix(corner(float2(0, 1)), corner(float2(1, 1)), ease.x), ease.y);
}

[[visible]]
void crawlCallWater(realitykit::surface_parameters params)
{
    auto constants = params.material_constants();
    auto surface = params.surface();
    half3 colour = half3(constants.base_color_tint());
    surface.set_roughness(half(constants.roughness_scale()));
    surface.set_metallic(half(constants.metallic_scale()));
    surface.set_specular(half(constants.specular_scale()));
    // The water can be partly seen through (FR-MAP-280). A custom material drops the
    // opacity its blending is given, so the opacity comes in the clearcoat's
    // roughness, and the water has no clearcoat (ADR-0039).
    surface.set_opacity(half(saturate(constants.clearcoat_roughness_scale())));
    surface.set_clearcoat(half(0.0));

    float4 ripple = params.uniforms().custom_parameter();
    float wavelength = ripple.x;
    if (!(wavelength > 0.0)) {                   // no ripple asked for
        surface.set_base_color(colour);
        return;
    }
    float2 world = params.geometry().world_position().xz;
    float time = params.uniforms().time();
    float2 here = world / wavelength;
    float drift = time * kDrift;
    float2 bent = world + wavelength * kBend
        * float2(noise(here / kBendSpan + drift), noise(here / kBendSpan + 17.0 - drift));
    float height = mix(kLowest, 1.0, noise(here / kHeightSpan + 41.0 + drift) * 0.5 + 0.5);

    // The longest wave's number of waves a metre, in radians, and its turns a second
    // at deep water's speed slowed by the configured share; each shorter wave's are
    // these times its own factors.
    float k0 = 2.0 * M_PI_F / wavelength;
    float turnsPerSecond = sqrt(kGravity * k0) * ripple.y / (2.0 * M_PI_F);
    float crest = 0.0;
    float2 slope = float2(0.0);                  // rise over run along x and along z
    for (int wave = 0; wave < kWaves; ++wave) {
        // The turns are counted modulo one so that a long session keeps its precision.
        float turns = fract(turnsPerSecond * kFasterBy[wave] * time);
        float phase = k0 * kShorterBy[wave] * dot(bent, kDirection[wave]) - 2.0 * M_PI_F * turns + kStart[wave];
        float cosine;
        float sine = sincos(phase, cosine);
        float shape = kWeight[wave] * exp(sine - 1.0);
        crest += shape;
        slope += shape * cosine * kDirection[wave];
    }
    // The slope of a·exp(sin(kx) − 1) is a·k·exp(…)·cos(…), with a taken as its
    // weight over k; summed over waves in random phases it spreads as the root of the
    // sum of squared weights, and is scaled so that its typical size is the
    // configured steepness.
    slope *= height * ripple.w / (kSlopeSpread * kSpreadOfWeights);
    float above = (crest - kMeanShape * kWeights) / (kShapeSpread * kSpreadOfWeights);
    float glint = smoothstep(kGlintFrom, kGlintFull, above) * height;
    surface.set_base_color(mix(colour, half3(1.0), half(glint * saturate(ripple.z))));

    // The tilted normal, in the world and then in the geometry's tangent space.
    auto geometry = params.geometry();
    float3 tilted = normalize(float3(-slope.x, 1.0, -slope.y));
    surface.set_normal(float3(dot(tilted, geometry.tangent()), dot(tilted, geometry.bitangent()),
                              dot(tilted, geometry.normal())));
}
