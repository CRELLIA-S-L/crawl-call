// The floor under the water (FR-MAP-270), coloured by how far down its slope it lies:
// the material's own colour at the edge, where it meets the shore, and the colour it
// carries in its custom value at the full depth, with the share between them taken
// from the first texture coordinate, which the floor's mesh sets at every vertex —
// 0 at the edge, 1 at depth. Matt, as the rest of the island.
//
// The custom value is the one four-component value a material carries: xyz the
// colour at depth. The contract is the SDK's own (RealityKitSurfaceShader.h, iOS 27.0
// SDK), as for the water above it (WaterRipple.metal).
//
// implements: FR-MAP-270
#include <RealityKit/RealityKit.h>

using namespace metal;

[[visible]]
void crawlCallFloor(realitykit::surface_parameters params)
{
    auto constants = params.material_constants();
    auto surface = params.surface();
    half3 edge = half3(constants.base_color_tint());
    half3 deep = half3(params.uniforms().custom_parameter().xyz);
    half share = half(saturate(params.geometry().uv0().x));
    surface.set_base_color(mix(edge, deep, share));
    surface.set_roughness(half(constants.roughness_scale()));
    surface.set_metallic(half(constants.metallic_scale()));
}
