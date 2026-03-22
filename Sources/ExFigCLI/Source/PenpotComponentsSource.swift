import ExFigCore
import Foundation
import PenpotAPI

struct PenpotComponentsSource: ComponentsSource {
    let ui: TerminalUI

    func loadIcons(from input: IconsSourceInput) async throws -> IconsLoadOutput {
        let packs = try await loadComponents(
            fileId: input.figmaFileId,
            baseURL: input.penpotBaseURL,
            pathFilter: input.frameName,
            sourceKind: input.sourceKind
        )
        return IconsLoadOutput(light: packs)
    }

    func loadImages(from input: ImagesSourceInput) async throws -> ImagesLoadOutput {
        let packs = try await loadComponents(
            fileId: input.figmaFileId,
            baseURL: input.penpotBaseURL,
            pathFilter: input.frameName,
            sourceKind: input.sourceKind
        )
        return ImagesLoadOutput(light: packs)
    }

    // MARK: - Private

    private func loadComponents(
        fileId: String?,
        baseURL: String?,
        pathFilter: String,
        sourceKind: DesignSourceKind
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

            guard let svgString = PenpotShapeRenderer.renderSVG(
                objects: objects, rootId: instanceId
            ) else {
                ui.warning("Component '\(component.name)' — failed to reconstruct SVG, skipping")
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
