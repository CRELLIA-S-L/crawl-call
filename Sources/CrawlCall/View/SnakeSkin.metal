// The snake's skin (FR-VIEW-270): the material's green, paler along the belly, with
// darker spots on the back and sides. The spots are laid out on the body, not in the
// world — by the first texture coordinate the body's mesh sets at every vertex, x the
// metres along it from the head's end and y the share of the way round it
// (`SnakeBody`) — so they go where the snake goes.
//
// The spots are a scatter: the body's surface is cut into cells a spot's spacing
// across, a whole number of them round the body so that no seam shows where the way
// round starts again, and each cell holds one spot or none, at a place and of a size
// its own. The back is told from the belly by the world normal: the camera looks down.
//
// The custom value is the one four-component value a material carries: xyz the spots'
// colour, w the body's radius in metres, which turns the share of the way round into
// metres. The contract is the SDK's own (RealityKitSurfaceShader.h, iOS 27.0 SDK), as
// for the water and the floor (WaterRipple.metal, SeaFloor.metal).
//
// implements: FR-VIEW-270
#include <RealityKit/RealityKit.h>

using namespace metal;

/// Metres from one spot's cell to the next, a spot's radius at most as a share of
/// that, the share of cells that hold no spot, how far off the cell's centre a spot
/// may sit as a share of the cell, and the soft edge of a spot as a share of its
/// radius. Settled by eye on the phone.
constant float kSpacing = 0.3;
constant float kLargest = 0.36;
constant float kEmpty = 0.3;
constant float kJitter = 0.28;
constant float kEdge = 0.25;
/// How pale the belly is — the share of the way from the green to white — and where
/// on the world normal's height the belly begins and the back is fully the back.
constant float kBelly = 0.45;
constant float kBellyFrom = -0.55;
constant float kBackFrom = -0.1;

/// Three numbers from 0 to 1 fixed for a cell.
static float3 scatter(float2 cell)
{
    float3 p = float3(dot(cell, float2(127.1, 311.7)), dot(cell, float2(269.5, 183.3)), dot(cell, float2(419.2, 371.9)));
    return fract(sin(p) * 43758.5453);
}

[[visible]]
void crawlCallSnakeSkin(realitykit::surface_parameters params)
{
    auto constants = params.material_constants();
    auto surface = params.surface();
    half3 green = half3(constants.base_color_tint());
    surface.set_roughness(half(constants.roughness_scale()));
    surface.set_metallic(half(constants.metallic_scale()));
    surface.set_specular(half(constants.specular_scale()));

    float4 skin = params.uniforms().custom_parameter();
    float2 uv = params.geometry().uv0();
    float up = params.geometry().normal().y;
    float back = smoothstep(kBellyFrom, kBackFrom, up);

    // Spots: cells a spacing long along the body and a whole number of them round it.
    float round = max(2.0 * M_PI_F * skin.w, kSpacing);
    float cellsRound = max(floor(round / kSpacing), 3.0);
    float2 place = float2(uv.x / kSpacing, uv.y * cellsRound);
    float2 cell = floor(place);
    float spot = 0.0;
    for (int dx = -1; dx <= 1; ++dx) {
        for (int dy = -1; dy <= 1; ++dy) {
            float2 near = cell + float2(dx, dy);
            float2 wrapped = float2(near.x, near.y - cellsRound * floor(near.y / cellsRound));
            float3 own = scatter(wrapped);
            if (own.z < kEmpty) { continue; }
            float2 centre = near + 0.5 + (own.xy - 0.5) * 2.0 * kJitter;
            float size = kLargest * (0.55 + 0.45 * own.x);
            float gap = length(place - centre);
            spot = max(spot, 1.0 - smoothstep(size * (1.0 - kEdge), size, gap));
        }
    }
    half3 belly = mix(green, half3(1.0), half(kBelly));
    half3 colour = mix(belly, green, half(back));
    colour = mix(colour, half3(skin.xyz), half(spot * back));
    surface.set_base_color(colour);
}
