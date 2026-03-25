#if canImport(XcodeProj)
    import Foundation
    import PathKit
    import XcodeProj

    enum XcodeProjectWriterError: LocalizedError {
        case unableToFindTarget(String)

        var errorDescription: String? {
            switch self {
            case let .unableToFindTarget(name):
                "Target not found: \(name)"
            }
        }

        var recoverySuggestion: String? {
            switch self {
            case .unableToFindTarget:
                "Check target name in Xcode project settings"
            }
        }
    }

    final class XcodeProjectWriter {
        let xcodeprojPath: Path
        let rootPath = Path("./")
        let xcodeproj: XcodeProj
        let pbxproj: PBXProj
        let myTarget: PBXTarget
        let project: PBXProject

        init(xcodeProjPath: String, target: String) throws {
            xcodeprojPath = Path(xcodeProjPath)
            xcodeproj = try XcodeProj(path: xcodeprojPath)
            pbxproj = xcodeproj.pbxproj
            if let target = pbxproj.targets(named: target).first {
                myTarget = target
            } else {
                throw XcodeProjectWriterError.unableToFindTarget(target)
            }
            guard let firstProject = pbxproj.projects.first else {
                throw XcodeProjectWriterError.unableToFindTarget("No project found")
            }
            project = firstProject
        }

        func addFileReferenceToXcodeProj(_ url: URL) throws {
            var groups = url.pathComponents
                .filter { $0 != "." }
                .dropLast() as Array

            var currentGroup: PBXGroup? = project.mainGroup
            var prevGroup: PBXGroup?

            while currentGroup != nil {
                if groups.isEmpty { break }
                let group = currentGroup?.children.first(where: { group -> Bool in
                    group.path == groups.first
                })
                if let group {
                    prevGroup = currentGroup
                    currentGroup = group as? PBXGroup
                    groups = Array(groups.dropFirst())
                } else {
                    prevGroup = currentGroup
                    let groupName = groups[0]
                    currentGroup = try prevGroup?.addGroup(named: groupName).first
                    groups = Array(groups.dropFirst())
                }
            }
            guard currentGroup?.children.first(where: { $0.path == url.lastPathComponent }) == nil else { return }

            let newFile = try currentGroup?.addFile(
                at: Path(url.path),
                sourceTree: .group,
                sourceRoot: rootPath,
                override: false,
                validatePresence: true
            )
            newFile?.fileEncoding = 4 // UTF-8
            newFile?.name = url.lastPathComponent

            if let file = newFile, let buildPhase = myTarget.buildPhases.first(where: { $0.buildPhase == .sources }) {
                _ = try buildPhase.add(file: file)
            }
        }

        func save() throws {
            try xcodeproj.write(path: xcodeprojPath)
        }
    }
#endif
