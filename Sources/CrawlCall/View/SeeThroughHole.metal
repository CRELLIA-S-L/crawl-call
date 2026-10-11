// The hole a module is cut open with, where it stands in the way of the snake or near
// the head (ADR-0020). The module is drawn as the kit colours it, and its opacity falls
// off towards the hole: clear inside, solid beyond a radius, and a soft rim between so
// the edge is not a cut line.
//
// The hole comes from the view (SeeThrough.holes), one per module, in the one
// four-component value a material carries: xyz a point in world metres, w the radius.
// A positive radius cuts a sphere around the point — the window around the head. A
// negative one cuts along the line of sight from the camera to the point, and only
// nearer the camera than the point — the snake seen through what stands in front of it.
// That is the shape the view cannot send as a sphere without clearing a thin partition
// whole, because a steep line of sight stays near such a partition for a metre and more.
//
// The contract is the SDK's own (RealityKitSurfaceShader.h, iOS 27.0 SDK): a surface
// shader is a [[visible]] function taking one surface_parameters; it must set the base
// colour or the entity renders white; custom_parameter() carries a value RealityKit
// gives no meaning to.
//
// file implements: FR-VIEW-150, FR-VIEW-155
#include <RealityKit/RealityKit.h>

using namespace metal;

/// How much of the module is left at the centre of the hole. Settled by eye on the
/// phone; it moves to the view configuration if it ever has to be tuned per map.
constant float kLeftAtCentre = 0.12;
/// The rim is the outer part of the radius, as a share of it.
constant float kRimShare = 0.35;

[[visible]]
void crawlCallHole(realitykit::surface_parameters params)
{
    auto constants = params.material_constants();
    auto surface = params.surface();

    // Nothing is set for us: a shader that sets no base colour renders the module
    // white, so the kit's own look is passed through first.
    surface.set_base_color(half3(constants.base_color_tint()));
    surface.set_roughness(half(constants.roughness_scale()));
    surface.set_metallic(half(constants.metallic_scale()));

    float4 hole = params.uniforms().custom_parameter();
    if (hole.w == 0.0 || isnan(hole.w)) {       // no hole asked for, and none cut
        surface.set_opacity(half(1.0));
        return;
    }
    float3 here = params.geometry().world_position();
    float radius = abs(hole.w);
    float gap;
    if (hole.w > 0.0) {
        gap = distance(here, hole.xyz);
    } else {
        // The camera, from the view matrix. World to view is p -> R p + t, and the view
        // puts the camera at its origin, so in the world the camera is at -R^T t. The
        // matrix is the camera's own and carries no scale.
        float4x4 view = params.uniforms().world_to_view();
        float3x3 turn = float3x3(view[0].xyz, view[1].xyz, view[2].xyz);
        float3 eye = -(transpose(turn) * view[3].xyz);
        float3 toPoint = hole.xyz - eye;
        float reach = length(toPoint);
        float3 unit = toPoint / reach;
        float3 fromEye = here - eye;
        float depth = dot(fromEye, unit);
        if (depth > reach) {                    // beyond the snake: it hides nothing
            surface.set_opacity(half(1.0));
            return;
        }
        gap = length(fromEye - depth * unit);
    }
    float solidity = smoothstep(radius * (1.0 - kRimShare), radius, gap);
    surface.set_opacity(half(mix(kLeftAtCentre, 1.0, solidity)));
}
