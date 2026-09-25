// Greenholm's water with waves and glints moving across it (FR-GREENHOLM-070,
// ADR-0038). The water keeps the colour and the roughness its material was made
// with. Three crossing waves tilt its normal, so that the sun lights the slopes
// facing it and the gloss catches it on them; and where the waves run high together
// the colour is lifted towards white, a pale crest. Slow noise bends the crests and
// lets the waves rise and fall from place to place, so that they do not form a grid.
//
// The waves are laid out in world metres, not in the mesh's own space, so that the
// bands along the shore and the slabs beyond them ripple as one surface, with no
// seam where two meet.
//
// The ripple comes from the material, in the one four-component value a material
// carries: x the wavelength in metres, y the speed in metres a second, z how far a
// crest lifts the colour towards white, 0 to 1, w the waves' steepness as rise over
// run. The normal is worked out in the world and handed over in the tangent space of
// the fragment's geometry, which every water mesh carries. The contract is the SDK's own
// (RealityKitSurfaceShader.h, iOS 27.0 SDK), as for the hole shader beside the
// modules (SeeThroughHole.metal).
//
// implements: FR-GREENHOLM-070
#include <RealityKit/RealityKit.h>

using namespace metal;

/// The waves: a direction each on the ground, and how much longer and faster each is
/// than the wavelength. Crossing at odd angles and odd ratios, so that the pattern
/// does not repeat where the eye would catch it. Settled by eye on the phone.
constant int kWaves = 5;
constant float2 kDirections[kWaves] = {
    float2(0.8, 0.6), float2(-0.47, 0.88), float2(0.26, -0.97), float2(-0.93, -0.37), float2(0.64, -0.77),
};
constant float kLengths[kWaves] = { 1.0, 0.73, 1.37, 0.59, 1.9 };
constant float kSpeeds[kWaves] = { 1.0, -0.83, 1.19, 0.71, -1.07 };
/// Slow noise bends the crests and lets the waves rise and fall from place to place,
/// so that no line of them runs straight across the water: how many wavelengths one
/// lump of it spans, how far it moves the waves, in wavelengths, how low it lets
/// them fall, as a share of their full height, and how fast it drifts.
constant float kBendSpan = 3.1;
constant float kBend = 0.45;
constant float kHeightSpan = 5.3;
constant float kLowest = 0.35;
constant float kDrift = 0.07;
/// Where on the mean of the waves, from -1 to 1, a crest begins and where it is full:
/// lower than for three waves, since the mean of five runs high less often.
constant float kGlintFrom = 0.35;
constant float kGlintFull = 0.7;

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

    float4 ripple = params.uniforms().custom_parameter();
    float wavelength = ripple.x;
    if (!(wavelength > 0.0)) {                   // no ripple asked for
        surface.set_base_color(colour);
        return;
    }
    float2 here = params.geometry().world_position().xz / wavelength;
    float travelled = params.uniforms().time() * ripple.y / wavelength;
    float drift = travelled * kDrift;
    float2 bent = here + kBend * float2(noise(here / kBendSpan + drift), noise(here / kBendSpan + 17.0 - drift));
    float height = mix(kLowest, 1.0, noise(here / kHeightSpan + 41.0 + drift) * 0.5 + 0.5);
    float sum = 0.0;
    float2 slope = float2(0.0);                  // rise over run along x and along z
    for (int wave = 0; wave < kWaves; ++wave) {
        float phase = (dot(bent, kDirections[wave]) / kLengths[wave] - travelled * kSpeeds[wave]) * 2.0 * M_PI_F;
        sum += sin(phase);
        slope += cos(phase) * kDirections[wave] / kLengths[wave];
    }
    slope *= height * ripple.w / float(kWaves);
    float glint = smoothstep(kGlintFrom, kGlintFull, height * sum / float(kWaves));
    surface.set_base_color(mix(colour, half3(1.0), half(glint * saturate(ripple.z))));

    // The tilted normal, in the world and then in the geometry's tangent space.
    auto geometry = params.geometry();
    float3 tilted = normalize(float3(-slope.x, 1.0, -slope.y));
    surface.set_normal(float3(dot(tilted, geometry.tangent()), dot(tilted, geometry.bitangent()),
                              dot(tilted, geometry.normal())));
}
