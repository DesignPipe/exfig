import Foundation
@testable import PenpotAPI
import Testing

@Suite("PenpotShapeRenderer")
struct PenpotShapeRendererTests {
    // MARK: - Basic Rendering

    @Test("Renders simple path icon")
    func simplePath() throws {
        let objects = makeObjects(
            root: makeFrame(id: "root", x: 100, y: 200, width: 16, height: 16, children: ["path1"]),
            children: [
                "path1": makePathShape(
                    content: "M106.0,204.0L108.0,208.0L110.0,204.0",
                    strokeColor: "#333333"
                ),
            ]
        )

        let svg = PenpotShapeRenderer.renderSVG(objects: objects, rootId: "root")
        let result = try #require(svg)

        #expect(result.contains("viewBox=\"0 0 16 16\""))
        #expect(result.contains("<path"))
        #expect(result.contains("stroke=\"#333333\""))
        // Coordinates should be normalized (100 subtracted from X, 200 from Y)
        #expect(result.contains("M6"))
        #expect(!result.contains("M106"))
    }

    @Test("Renders rect with fill")
    func rectWithFill() throws {
        let objects = makeObjects(
            root: makeFrame(id: "root", x: 0, y: 0, width: 24, height: 24, children: ["rect1"]),
            children: [
                "rect1": PenpotShape(
                    id: "rect1", name: "bg", type: "rect",
                    x: 2, y: 2, width: 20, height: 20, rotation: nil, selrect: nil,
                    content: nil,
                    fills: [.init(fillColor: "#FF0000", fillOpacity: 0.5)],
                    strokes: nil, svgAttrs: nil, hideFillOnExport: nil,
                    shapes: nil, boolType: nil, r1: 4, r2: nil, r3: nil, r4: nil,
                    transform: nil, opacity: nil, hidden: nil
                ),
            ]
        )

        let svg = PenpotShapeRenderer.renderSVG(objects: objects, rootId: "root")
        let result = try #require(svg)

        #expect(result.contains("<rect"))
        #expect(result.contains("x=\"2\""))
        #expect(result.contains("y=\"2\""))
        #expect(result.contains("width=\"20\""))
        #expect(result.contains("height=\"20\""))
        #expect(result.contains("rx=\"4\""))
        #expect(result.contains("fill=\"#FF0000\""))
        #expect(result.contains("fill-opacity=\"0.5\""))
    }

    @Test("Renders circle/ellipse")
    func ellipse() throws {
        let objects = makeObjects(
            root: makeFrame(id: "root", x: 0, y: 0, width: 16, height: 16, children: ["circle1"]),
            children: [
                "circle1": PenpotShape(
                    id: "circle1", name: "dot", type: "circle",
                    x: 4, y: 4, width: 8, height: 8, rotation: nil, selrect: nil,
                    content: nil,
                    fills: [.init(fillColor: "#00FF00", fillOpacity: 1.0)],
                    strokes: nil, svgAttrs: nil, hideFillOnExport: nil,
                    shapes: nil, boolType: nil, r1: nil, r2: nil, r3: nil, r4: nil,
                    transform: nil, opacity: nil, hidden: nil
                ),
            ]
        )

        let svg = PenpotShapeRenderer.renderSVG(objects: objects, rootId: "root")
        let result = try #require(svg)

        #expect(result.contains("<ellipse"))
        #expect(result.contains("cx=\"8\""))
        #expect(result.contains("cy=\"8\""))
        #expect(result.contains("rx=\"4\""))
        #expect(result.contains("ry=\"4\""))
    }

    @Test("Renders bool type as path")
    func boolPath() throws {
        let objects = makeObjects(
            root: makeFrame(id: "root", x: 0, y: 0, width: 16, height: 16, children: ["bool1"]),
            children: [
                "bool1": PenpotShape(
                    id: "bool1", name: "Union", type: "bool",
                    x: nil, y: nil, width: nil, height: nil, rotation: nil, selrect: nil,
                    content: .path("M2,4L8,2L14,4L14,12L8,14L2,12Z"),
                    fills: [.init(fillColor: "#0000FF", fillOpacity: 1.0)],
                    strokes: nil, svgAttrs: nil, hideFillOnExport: nil,
                    shapes: nil, boolType: "union", r1: nil, r2: nil, r3: nil, r4: nil,
                    transform: nil, opacity: nil, hidden: nil
                ),
            ]
        )

        let svg = PenpotShapeRenderer.renderSVG(objects: objects, rootId: "root")
        let result = try #require(svg)

        #expect(result.contains("<path"))
        #expect(result.contains("d=\"M2,4L8,2L14,4L14,12L8,14L2,12Z\""))
        #expect(result.contains("fill=\"#0000FF\""))
    }

    @Test("Hidden shapes are skipped")
    func hiddenShape() throws {
        let objects = makeObjects(
            root: makeFrame(id: "root", x: 0, y: 0, width: 16, height: 16, children: ["visible", "hidden"]),
            children: [
                "visible": makePathShape(content: "M0,0L16,16", strokeColor: "#000"),
                "hidden": PenpotShape(
                    id: "hidden", name: "hidden", type: "path",
                    x: nil, y: nil, width: nil, height: nil, rotation: nil, selrect: nil,
                    content: .path("M0,16L16,0"),
                    fills: nil, strokes: nil, svgAttrs: nil, hideFillOnExport: nil,
                    shapes: nil, boolType: nil, r1: nil, r2: nil, r3: nil, r4: nil,
                    transform: nil, opacity: nil, hidden: true
                ),
            ]
        )

        let svg = PenpotShapeRenderer.renderSVG(objects: objects, rootId: "root")
        let result = try #require(svg)

        #expect(result.contains("M0,0L16,16"))
        #expect(!result.contains("M0,16L16,0"))
    }

    @Test("Returns nil for missing root")
    func missingRoot() {
        let svg = PenpotShapeRenderer.renderSVG(objects: [:], rootId: "nonexistent")
        #expect(svg == nil)
    }

    @Test("Empty fills produce fill=none")
    func emptyFillsNone() throws {
        let objects = makeObjects(
            root: makeFrame(id: "root", x: 0, y: 0, width: 16, height: 16, children: ["p"]),
            children: [
                "p": PenpotShape(
                    id: "p", name: "line", type: "path",
                    x: nil, y: nil, width: nil, height: nil, rotation: nil, selrect: nil,
                    content: .path("M0,0L16,16"),
                    fills: [],
                    strokes: [.init(
                        strokeColor: "#000",
                        strokeOpacity: 1,
                        strokeWidth: 1,
                        strokeStyle: "solid",
                        strokeAlignment: nil,
                        strokeCapStart: nil,
                        strokeCapEnd: nil
                    )],
                    svgAttrs: nil, hideFillOnExport: nil,
                    shapes: nil, boolType: nil, r1: nil, r2: nil, r3: nil, r4: nil,
                    transform: nil, opacity: nil, hidden: nil
                ),
            ]
        )

        let svg = try #require(PenpotShapeRenderer.renderSVG(objects: objects, rootId: "root"))
        #expect(svg.contains("fill=\"none\""))
        #expect(svg.contains("stroke=\"#000\""))
    }

    // MARK: - Coordinate Normalization

    @Test("normalizePathCoordinates subtracts origin")
    func normalizeCoords() {
        let path = "M110.0,205.0L115.0,210.0"
        let result = PenpotShapeRenderer.normalizePathCoordinates(path, originX: 100, originY: 200)
        #expect(result == "M10,5L15,10")
    }

    @Test("normalizePathCoordinates handles negative results")
    func normalizeNegative() {
        let path = "M50.0,50.0L60.0,60.0"
        let result = PenpotShapeRenderer.normalizePathCoordinates(path, originX: 55, originY: 55)
        #expect(result.contains("-5"))
    }

    // MARK: - Helpers

    // swiftlint:disable:next function_parameter_count
    private func makeFrame(
        id: String, x: Double, y: Double, width: Double, height: Double, children: [String]
    ) -> PenpotShape {
        PenpotShape(
            id: id, name: "frame", type: "frame",
            x: x, y: y, width: width, height: height, rotation: nil,
            selrect: .init(x: x, y: y, width: width, height: height),
            content: nil, fills: nil, strokes: nil, svgAttrs: nil, hideFillOnExport: nil,
            shapes: children, boolType: nil, r1: nil, r2: nil, r3: nil, r4: nil,
            transform: nil, opacity: nil, hidden: nil
        )
    }

    private func makePathShape(content: String, strokeColor: String) -> PenpotShape {
        PenpotShape(
            id: UUID().uuidString, name: "path", type: "path",
            x: nil, y: nil, width: nil, height: nil, rotation: nil, selrect: nil,
            content: .path(content),
            fills: [],
            strokes: [.init(
                strokeColor: strokeColor,
                strokeOpacity: 1,
                strokeWidth: 1,
                strokeStyle: "solid",
                strokeAlignment: "center",
                strokeCapStart: "round",
                strokeCapEnd: "round"
            )],
            svgAttrs: nil,
            hideFillOnExport: nil,
            shapes: nil, boolType: nil, r1: nil, r2: nil, r3: nil, r4: nil,
            transform: nil, opacity: nil, hidden: nil
        )
    }

    private func makeObjects(root: PenpotShape, children: [String: PenpotShape]) -> [String: PenpotShape] {
        var objects = children
        objects[root.id] = root
        return objects
    }
}
