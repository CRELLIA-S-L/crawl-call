// A bot going into the snake's mouth from the top down (FR-VIEW-320): drawn as its
// own material draws it below a level plane — the mouth of the head coming down over
// it — and not at all above, where it is inside the head. What is cut away is thrown
// out by the material's opacity threshold, so the rest of the figure stays opaque.
//
// The custom value is the one four-component value a material carries: x the height of
// the cut, in world metres. The contract is the SDK's own (RealityKitSurfaceShader.h,
// iOS 27.0 SDK): a surface shader sets the base colour or the entity renders white, and
// the material's own values reach it through material_constants().
//
// file implements: FR-VIEW-320
#include <RealityKit/RealityKit.h>

using namespace metal;

[[visible]]
void crawlCallBotCut(realitykit::surface_parameters params)
{
    auto constants = params.material_constants();
    auto surface = params.surface();
    surface.set_base_color(half3(constants.base_color_tint()));
    surface.set_emissive_color(half3(constants.emissive_color()));
    surface.set_roughness(half(constants.roughness_scale()));
    surface.set_metallic(half(constants.metallic_scale()));
    float cut = params.uniforms().custom_parameter().x;
    surface.set_opacity(params.geometry().world_position().y > cut ? half(0.0) : half(1.0));
}
