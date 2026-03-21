import ExFigCore
import Foundation
import PenpotAPI

struct PenpotComponentsSource: ComponentsSource {
    let ui: TerminalUI

    func loadIcons(from input: IconsSourceInput) async throws -> IconsLoadOutput {
        // Warn about raster-only limitation when SVG requested
        if input.format == .svg {
            ui.warning(
                "Penpot API provides raster thumbnails only — SVG format is not available. " +
                    "Icons will be exported as PNG thumbnails."
            )
        }

        let packs = try await loadComponents(
            fileId: input.figmaFileId ?? "",
            pathFilter: input.frameName,
            sourceKind: input.sourceKind
        )

        return IconsLoadOutput(light: packs)
    }

    func loadImages(from input: ImagesSourceInput) async throws -> ImagesLoadOutput {
        let packs = try await loadComponents(
            fileId: input.figmaFileId ?? "",
            pathFilter: input.frameName,
            sourceKind: input.sourceKind
        )

        return ImagesLoadOutput(light: packs)
    }

    // MARK: - Private

    private func loadComponents(
        fileId: String,
        pathFilter: String,
        sourceKind: DesignSourceKind
    ) async throws -> [ImagePack] {
        let client = try PenpotColorsSource.makeClient(
            baseURL: BasePenpotClient.defaultBaseURL
        )

        let fileResponse = try await client.request(GetFileEndpoint(fileId: fileId))

        guard let components = fileResponse.data.components else {
            return []
        }

        // Filter components by path
        let matchedComponents = components.values.filter { component in
            guard let path = component.path else { return false }
            return path.hasPrefix(pathFilter)
        }

        guard !matchedComponents.isEmpty else {
            return []
        }

        // Get thumbnails for matched components
        let objectIds = matchedComponents.map(\.id)
        let thumbnails = try await client.request(
            GetFileObjectThumbnailsEndpoint(fileId: fileId, objectIds: objectIds)
        )

        var packs: [ImagePack] = []

        for component in matchedComponents {
            guard let thumbnailRef = thumbnails[component.id] else {
                ui.warning("Component '\(component.name)' has no thumbnail — skipping")
                continue
            }

            // Build download URL for the thumbnail
            let downloadPath = thumbnailRef.hasPrefix("http") ? thumbnailRef : "assets/by-file-media-id/\(thumbnailRef)"

            guard let url = URL(string: downloadPath
                .hasPrefix("http") ? downloadPath : "https://design.penpot.app/\(downloadPath)")
            else {
                ui.warning("Component '\(component.name)' has invalid thumbnail URL — skipping")
                continue
            }

            let image = Image(
                name: component.name,
                scale: .individual(1.0),
                url: url,
                format: "png"
            )

            packs.append(ImagePack(
                name: component.name,
                images: [image],
                nodeId: component.id,
                fileId: fileId
            ))
        }

        return packs
    }
}
