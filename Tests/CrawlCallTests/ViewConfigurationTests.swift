// The camera's framing and the light are read from the view configuration
// (IF-VIEW-020): a scene built from a configuration with other numbers in it has
// those numbers, which it cannot have if they are written anywhere but in the file.
//
// verifies: IF-VIEW-020
import RealityKit
import XCTest
@testable import CrawlCall

@MainActor
final class ViewConfigurationTests: XCTestCase {
    /// The shipped view configuration with some keys replaced.
    private func view(_ changes: [String: Any]) throws -> ViewConfiguration {
        let url = try XCTUnwrap(Bundle.main.url(forResource: "view", withExtension: "json", subdirectory: "config"))
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
        for (key, value) in changes { json[key] = value }
        return try Configurations.decode(ViewConfiguration.self, named: "view", schema: ViewConfiguration.schema,
                                         from: JSONSerialization.data(withJSONObject: json))
    }

    func testTheCameraAndTheLightTakeTheirNumbersFromTheConfiguration() throws {
        let world = try Launch.world().get()
        let changed = try view(["cameraFieldOfView": 37, "sunIntensity": 4321,
                                "ambientIntensityExponent": 0.5, "cameraDistanceInMapWidths": 2])
        let scene = SceneBuilder.scene(for: world.plan, view: changed).root

        let camera = try XCTUnwrap(scene.children.first { $0.name == EntityName.camera } as? PerspectiveCamera)
        XCTAssertEqual(camera.camera.fieldOfViewInDegrees, 37, accuracy: 1e-5)

        let sun = try XCTUnwrap(scene.children.first { $0.name == EntityName.light } as? DirectionalLight)
        XCTAssertEqual(sun.light.intensity, 4321, accuracy: 1e-3)

        let ambient = try XCTUnwrap(scene.children.first { $0.name == EntityName.ambient })
        let component = try XCTUnwrap(ambient.components[ImageBasedLightComponent.self])
        XCTAssertEqual(component.intensityExponent, 0.5, accuracy: 1e-6)

        // Twice the map's larger side back from what it frames.
        let span = max(world.plan.bounds.extent.x, world.plan.bounds.extent.z)
        XCTAssertEqual(SceneView.distance(framing: world.plan, view: changed), 2 * span, accuracy: 1e-9)
    }

    func testTheShippedLightIsTheOneTheSceneHadBeforeItMovedIntoTheFile() throws {
        // The numbers moved out of code on 2026-09-24 without changing the picture:
        // the sun sixty degrees down and thirty-six across, as it was at a third and
        // a fifth of a half turn.
        let shipped = try Launch.world().get().configurations.view
        XCTAssertEqual(SceneView.radians(shipped.sunElevation), Float.pi / 3, accuracy: 1e-6)
        XCTAssertEqual(SceneView.radians(shipped.sunAzimuth), Float.pi / 5, accuracy: 1e-6)
        XCTAssertEqual(shipped.cameraFieldOfView, 50)
        XCTAssertEqual(shipped.cameraDistanceInMapWidths, 1.1)
    }
}
