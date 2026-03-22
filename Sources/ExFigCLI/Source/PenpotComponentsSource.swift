import ExFigCore
import Foundation
import PenpotAPI

struct PenpotComponentsSource: ComponentsSource {
    let ui: TerminalUI

    func loadIcons(from input: IconsSourceInput) async throws -> IconsLoadOutput {
        let packs = try await loadComponents(
            fileId: input.figmaFileId,
            baseURL: input.penpotBaseURL,
            pathFilter: input.frameName
        )
        return IconsLoadOutput(light: packs)
    }

    func loadImages(from input: ImagesSourceInput) async throws -> ImagesLoadOutput {
        let packs = try await loadComponents(
            fileId: input.figmaFileId,
            baseURL: input.penpotBaseURL,
            pathFilter: input.frameName
        )
        return ImagesLoadOutput(light: packs)
    }

    // MARK: - Private

    private func loadComponents(
        fileId: String?,
        baseURL: String?,
        pathFilter: String
    ) async throws -> [ImagePack] {
        guard let fileId, !fileId.isEmpty else {
            throw ExFigError.configurationError(
                "Penpot file ID is required for components export — set penpotSource.fileId in your config"
            )
        }

        let effectiveBaseURL = baseURL ?? BasePenpotClient.defaultBaseURL
        let client = try PenpotClientFactory.makeClient(baseURL: effectiveBaseURL)

        let fileResponse = try await client.request(GetFileEndpoint(fileId: fileId))

        guard let components = fileResponse.data.components else {
            ui.warning("Penpot file '\(fileResponse.name)' has no library components")
            return []
        }

        // Filter components by path
        let matchedComponents = components.values.filter { component in
            guard let path = component.path else { return false }
            return path.hasPrefix(pathFilter)
        }

        let sortedComponents = matchedComponents.sorted { $0.name < $1.name }

        guard !sortedComponents.isEmpty else {
            let availablePaths = components.values
                .compactMap(\.path)
                .reduce(into: Set<String>()) { $0.insert($1) }
                .sorted()
                .prefix(5)
            let pathHint = availablePaths.isEmpty
                ? ""
                : " Available paths: \(availablePaths.joined(separator: ", "))"
            ui.warning("No components matching path prefix '\(pathFilter)'.\(pathHint)")
            return []
        }

        let packs = try reconstructSVGs(
            components: sortedComponents,
            fileResponse: fileResponse,
            fileId: fileId
        )

        if packs.isEmpty, !sortedComponents.isEmpty {
            ui.warning(
                "Found \(sortedComponents.count) components but could not reconstruct SVG for any. " +
                    "Components may lack mainInstanceId (not opened in Penpot editor)."
            )
        }

        return packs
    }

    private func reconstructSVGs(
        components: [PenpotComponent],
        fileResponse: PenpotFileResponse,
        fileId: String
    ) throws -> [ImagePack] {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("exfig-penpot-\(ProcessInfo.processInfo.processIdentifier)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        var packs: [ImagePack] = []

        for component in components {
            guard let pageId = component.mainInstancePage,
                  let instanceId = component.mainInstanceId,
                  let page = fileResponse.data.pagesIndex?[pageId],
                  let objects = page.objects
            else {
                ui.warning("Component '\(component.name)' has no shape data — skipping")
                continue
            }

            let renderResult = PenpotShapeRenderer.renderSVGResult(
                objects: objects, rootId: instanceId
            )
            let svgString: String
            switch renderResult {
            case let .success(result):
                svgString = result.svg
                if !result.skippedShapeTypes.isEmpty {
                    ui.warning(
                        "Component '\(component.name)' — unsupported shape types skipped: " +
                            result.skippedShapeTypes.sorted().joined(separator: ", ")
                    )
                }
            case let .failure(reason):
                switch reason {
                case let .rootNotFound(id):
                    ui.warning("Component '\(component.name)' — root shape '\(id)' not found, skipping")
                case let .missingSelrect(id):
                    ui.warning("Component '\(component.name)' — root shape '\(id)' has no bounds, skipping")
                }
                continue
            }

            let svgData = Data(svgString.utf8)
            let safeName = component.name
                .replacingOccurrences(of: "/", with: "_")
                .replacingOccurrences(of: " ", with: "_")
            let tempURL = tempDir.appendingPathComponent("\(safeName).svg")
            try svgData.write(to: tempURL)

            packs.append(ImagePack(
                name: component.name,
                images: [Image(name: component.name, scale: .all, url: tempURL, format: "svg")],
                nodeId: component.id,
                fileId: fileId
            ))
        }

        return packs
    }
}
