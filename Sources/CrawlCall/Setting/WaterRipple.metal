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
// implements: FR-GREENHOLM-070, FR-MAP-280
#include <RealityKit/RealityKit.h>

using namespace metal;

/// The waves, as ocean shaders build them (GPU Gems 1, ch. 1; Tessendorf, "Simulating
/// Ocean Water"): many, each shorter and lower than the one before, so that the water
/// has waves of every size and not one size repeated; each running at the speed deep
/// water carries a wave of its length, ω = √(g k), so that long waves overtake short
/// ones and the pattern never holds still; each in its own direction within a spread
/// round the wind; and each shaped exp(sin − 1), a narrow crest over a wide trough.
constant int kWaves = 12;
/// How much shorter each wave is than the one before, and how much lower.
constant float kShorter = 1.18;
constant float kLower = 0.82;
/// Where the wind comes from, and how far to either side of it, in radians, a wave may
/// run.
constant float2 kWind = float2(0.8, 0.6);
constant float kSpread = 1.05;
constant float kGravity = 9.81;
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

/// A number from 0 to 1 fixed for each whole number: a wave's direction and its start.
static float scatter(float n)
{
    return fract(sin(n * 12.9898) * 43758.5453);
}

/// Value noise: -1 to 1, smooth between the whole points of the plane.
static float noise(float2 p)
{
    float2 whole = floor(p);
    float2 part = p - whole;
    float2 ease = part * part * (3.0 - 2.0 * part);
    auto corner = [&](float2 offset) {
        return fract(sin(dot(whole + offset, float2(127.1, 311.7))) * 43758.5453) * 2.0 - 1.0;
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

    float2 wind = normalize(kWind);
    float span = wavelength, weight = 1.0, weights = 0.0, squares = 0.0, crest = 0.0;
    float2 slope = float2(0.0);                  // rise over run along x and along z
    for (int wave = 0; wave < kWaves; ++wave) {
        float turn = (scatter(float(wave)) * 2.0 - 1.0) * kSpread;
        float2 direction = float2(wind.x * cos(turn) - wind.y * sin(turn), wind.x * sin(turn) + wind.y * cos(turn));
        float k = 2.0 * M_PI_F / span;
        // Deep water's dispersion, slowed by the configured share; the turns are
        // counted modulo one so that a long session keeps its precision.
        float turns = fract(sqrt(kGravity * k) * ripple.y * time / (2.0 * M_PI_F));
        float phase = k * dot(bent, direction) - 2.0 * M_PI_F * turns + 2.0 * M_PI_F * scatter(float(wave) + 0.5);
        float shape = exp(sin(phase) - 1.0);
        crest += weight * shape;
        slope += weight * shape * cos(phase) * direction;
        weights += weight;
        squares += weight * weight;
        span /= kShorter;
        weight *= kLower;
    }
    // The slope of a·exp(sin(kx) − 1) is a·k·exp(…)·cos(…), with a taken as its
    // weight over k; summed over waves in random phases it spreads as the root of the
    // sum of squared weights, and is scaled so that its typical size is the
    // configured steepness.
    float spread = sqrt(squares);
    slope *= height * ripple.w / (kSlopeSpread * spread);
    float above = (crest - kMeanShape * weights) / (kShapeSpread * spread);
    float glint = smoothstep(kGlintFrom, kGlintFull, above) * height;
    surface.set_base_color(mix(colour, half3(1.0), half(glint * saturate(ripple.z))));

    // The tilted normal, in the world and then in the geometry's tangent space.
    auto geometry = params.geometry();
    float3 tilted = normalize(float3(-slope.x, 1.0, -slope.y));
    surface.set_normal(float3(dot(tilted, geometry.tangent()), dot(tilted, geometry.bitangent()),
                              dot(tilted, geometry.normal())));
}
