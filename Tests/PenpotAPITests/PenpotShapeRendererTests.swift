// swiftlint:disable file_length
import Foundation
@testable import PenpotAPI
import Testing

// swiftlint:disable type_body_length
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
                    id: "rect1", name: "bg", type: .rect,
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
                    id: "circle1", name: "dot", type: .circle,
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
                    id: "bool1", name: "Union", type: .bool,
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
                    id: "hidden", name: "hidden", type: .path,
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
                    id: "p", name: "line", type: .path,
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

    // MARK: - Nested Groups

    @Test("Renders nested group containing paths")
    func nestedGroup() throws {
        let innerPath = PenpotShape(
            id: "inner-path", name: "inner", type: .path,
            x: nil, y: nil, width: nil, height: nil, rotation: nil, selrect: nil,
            content: .path("M2,2L14,14"),
            fills: [.init(fillColor: "#FF0000", fillOpacity: 1.0)],
            strokes: nil, svgAttrs: nil, hideFillOnExport: nil,
            shapes: nil, boolType: nil, r1: nil, r2: nil, r3: nil, r4: nil,
            transform: nil, opacity: nil, hidden: nil
        )
        let group = PenpotShape(
            id: "group1", name: "group", type: .group,
            x: nil, y: nil, width: nil, height: nil, rotation: nil, selrect: nil,
            content: nil, fills: nil, strokes: nil, svgAttrs: nil, hideFillOnExport: nil,
            shapes: ["inner-path"], boolType: nil, r1: nil, r2: nil, r3: nil, r4: nil,
            transform: nil, opacity: nil, hidden: nil
        )
        let root = makeFrame(id: "root", x: 0, y: 0, width: 16, height: 16, children: ["group1"])
        var objects: [String: PenpotShape] = [:]
        objects["root"] = root
        objects["group1"] = group
        objects["inner-path"] = innerPath

        let svg = try #require(PenpotShapeRenderer.renderSVG(objects: objects, rootId: "root"))
        #expect(svg.contains("<g>"))
        #expect(svg.contains("<path"))
        #expect(svg.contains("M2,2L14,14"))
        #expect(svg.contains("</g>"))
    }

    @Test("Renders deeply nested frame inside group")
    func deepNesting() throws {
        let leaf = PenpotShape(
            id: "leaf", name: "leaf", type: .rect,
            x: 5, y: 5, width: 6, height: 6, rotation: nil, selrect: nil,
            content: nil, fills: [.init(fillColor: "#00FF00", fillOpacity: 1.0)],
            strokes: nil, svgAttrs: nil, hideFillOnExport: nil,
            shapes: nil, boolType: nil, r1: nil, r2: nil, r3: nil, r4: nil,
            transform: nil, opacity: nil, hidden: nil
        )
        let innerFrame = PenpotShape(
            id: "inner-frame", name: "inner", type: .frame,
            x: nil, y: nil, width: nil, height: nil, rotation: nil, selrect: nil,
            content: nil, fills: nil, strokes: nil, svgAttrs: nil, hideFillOnExport: nil,
            shapes: ["leaf"], boolType: nil, r1: nil, r2: nil, r3: nil, r4: nil,
            transform: nil, opacity: nil, hidden: nil
        )
        let group = PenpotShape(
            id: "g1", name: "wrapper", type: .group,
            x: nil, y: nil, width: nil, height: nil, rotation: nil, selrect: nil,
            content: nil, fills: nil, strokes: nil, svgAttrs: nil, hideFillOnExport: nil,
            shapes: ["inner-frame"], boolType: nil, r1: nil, r2: nil, r3: nil, r4: nil,
            transform: nil, opacity: nil, hidden: nil
        )
        let root = makeFrame(id: "root", x: 0, y: 0, width: 16, height: 16, children: ["g1"])
        let objects: [String: PenpotShape] = [
            "root": root, "g1": group, "inner-frame": innerFrame, "leaf": leaf,
        ]

        let svg = try #require(PenpotShapeRenderer.renderSVG(objects: objects, rootId: "root"))
        #expect(svg.contains("<rect"))
        #expect(svg.contains("fill=\"#00FF00\""))
    }

    // MARK: - Rotation Transform

    @Test("Rotation wraps shape in g transform")
    func rotationTransform() throws {
        let rect = PenpotShape(
            id: "rotated", name: "rotated", type: .rect,
            x: 4, y: 4, width: 8, height: 8, rotation: 45, selrect: nil,
            content: nil, fills: [.init(fillColor: "#0000FF", fillOpacity: 1.0)],
            strokes: nil, svgAttrs: nil, hideFillOnExport: nil,
            shapes: nil, boolType: nil, r1: nil, r2: nil, r3: nil, r4: nil,
            transform: nil, opacity: nil, hidden: nil
        )
        let root = makeFrame(id: "root", x: 0, y: 0, width: 16, height: 16, children: ["rotated"])
        let objects: [String: PenpotShape] = ["root": root, "rotated": rect]

        let svg = try #require(PenpotShapeRenderer.renderSVG(objects: objects, rootId: "root"))
        #expect(svg.contains("transform=\"rotate(45 8 8)\""))
        #expect(svg.contains("<rect"))
    }

    // MARK: - Relative Path Commands

    @Test("normalizePathCoordinates preserves relative commands")
    func relativeCommands() {
        let path = "M110,205l5,5"
        let result = PenpotShapeRenderer.normalizePathCoordinates(path, originX: 100, originY: 200)
        // M is absolute → offset, l is relative → no offset
        #expect(result.contains("M10,5"))
        #expect(result.contains("l5,5"))
    }

    // MARK: - Arc Command Normalization

    @Test("normalizePathCoordinates offsets only arc endpoint coordinates")
    func arcNormalization() {
        // A rx ry x-rotation large-arc-flag sweep-flag x y
        let path = "M110,205A10,10,0,0,1,120,215"
        let result = PenpotShapeRenderer.normalizePathCoordinates(path, originX: 100, originY: 200)
        // M → 10,5  A → rx=10 ry=10 xrot=0 large=0 sweep=1 x=20 y=15
        #expect(result == "M10,5A10,10,0,0,1,20,15")
    }

    // MARK: - Unknown Shape Types

    @Test("renderSVGResult reports unknown shape types")
    func unknownShapeTypes() throws {
        let textShape = PenpotShape(
            id: "text1", name: "label", type: .unknown("text"),
            x: nil, y: nil, width: nil, height: nil, rotation: nil, selrect: nil,
            content: nil, fills: nil, strokes: nil, svgAttrs: nil, hideFillOnExport: nil,
            shapes: nil, boolType: nil, r1: nil, r2: nil, r3: nil, r4: nil,
            transform: nil, opacity: nil, hidden: nil
        )
        let root = makeFrame(id: "root", x: 0, y: 0, width: 16, height: 16, children: ["text1"])
        let objects: [String: PenpotShape] = ["root": root, "text1": textShape]

        let renderResult = try PenpotShapeRenderer.renderSVGResult(objects: objects, rootId: "root").get()
        #expect(renderResult.skippedShapeTypes.contains("text"))
    }

    // MARK: - RenderFailure Diagnostics

    @Test("renderSVGResult returns rootNotFound for missing root")
    func renderFailureRootNotFound() {
        let result = PenpotShapeRenderer.renderSVGResult(objects: [:], rootId: "missing")
        switch result {
        case .success:
            Issue.record("Expected failure")
        case let .failure(reason):
            if case let .rootNotFound(id) = reason {
                #expect(id == "missing")
            } else {
                Issue.record("Expected rootNotFound")
            }
        }
    }

    @Test("renderSVGResult returns missingSelrect")
    func renderFailureMissingSelrect() {
        let noSelrect = PenpotShape(
            id: "root", name: "frame", type: .frame,
            x: 0, y: 0, width: 16, height: 16, rotation: nil, selrect: nil,
            content: nil, fills: nil, strokes: nil, svgAttrs: nil, hideFillOnExport: nil,
            shapes: [], boolType: nil, r1: nil, r2: nil, r3: nil, r4: nil,
            transform: nil, opacity: nil, hidden: nil
        )
        let result = PenpotShapeRenderer.renderSVGResult(objects: ["root": noSelrect], rootId: "root")
        switch result {
        case .success:
            Issue.record("Expected failure")
        case let .failure(reason):
            if case let .missingSelrect(id) = reason {
                #expect(id == "root")
            } else {
                Issue.record("Expected missingSelrect")
            }
        }
    }

    // MARK: - ShapeType Decoding

    @Test("ShapeType decodes known and unknown types")
    func shapeTypeDecoding() throws {
        let json = Data("""
        {"id": "1", "name": "test", "type": "svg-raw"}
        """.utf8)
        let shape = try JSONDecoder().decode(PenpotShape.self, from: json)
        #expect(shape.type == .unknown("svg-raw"))
        #expect(shape.type.description == "svg-raw")
    }

    // MARK: - Helpers

    // swiftlint:disable:next function_parameter_count
    private func makeFrame(
        id: String, x: Double, y: Double, width: Double, height: Double, children: [String]
    ) -> PenpotShape {
        PenpotShape(
            id: id, name: "frame", type: .frame,
            x: x, y: y, width: width, height: height, rotation: nil,
            selrect: .init(x: x, y: y, width: width, height: height),
            content: nil, fills: nil, strokes: nil, svgAttrs: nil, hideFillOnExport: nil,
            shapes: children, boolType: nil, r1: nil, r2: nil, r3: nil, r4: nil,
            transform: nil, opacity: nil, hidden: nil
        )
    }

    private func makePathShape(content: String, strokeColor: String) -> PenpotShape {
        PenpotShape(
            id: UUID().uuidString, name: "path", type: .path,
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
