import Foundation
import PklSwift

extension PklError: @retroactive LocalizedError {
    public var errorDescription: String? {
        message
    }
}

/// Evaluates PKL configuration files using pkl-swift's evaluator.
///
/// Spawns `pkl` CLI as a child process and communicates via MessagePack protocol.
/// Requires `pkl` 0.31+ in PATH (managed by mise).
///
/// Usage:
/// ```swift
/// let config = try await PKLEvaluator.evaluate(configPath: configURL)
/// print(config.ios?.colors) // [iOS.ColorsEntry]?
/// ```
public enum PKLEvaluator {
    /// Allowed module schemes (no http/https to prevent network imports).
    private static let allowedModules = [
        "pkl:", "repl:", "file:", "modulepath:", "package:", "projectpackage:",
    ]

    /// Allowed resource schemes.
    /// Includes https: because package: resolution requires downloading archives via HTTPS.
    /// Module imports (allowedModules) still block https: to prevent executing remote code.
    private static let allowedResources = [
        "file:", "env:", "prop:", "modulepath:", "package:", "projectpackage:", "https:",
    ]

    // swiftlint:disable identifier_name

    /// Thread-safe one-time registration of all generated PKL types.
    /// Bypasses O(N) type scanning on first eval — instant instead of scanning all types in binary.
    private static let _typeRegistration: Void = {
        registerPklTypes([
            // ExFig
            ExFig.ModuleImpl.self,
            // Common
            Common.Module.self,
            Common.VariablesSourceImpl.self,
            Common.NameProcessingImpl.self,
            Common.FrameSourceImpl.self,
            Common.TokensFile.self,
            Common.PenpotSource.self,
            Common.WebpOptions.self,
            Common.VariablesDarkMode.self,
            Common.SuffixDarkMode.self,
            Common.Cache.self,
            Common.Colors.self,
            Common.Icons.self,
            Common.Images.self,
            Common.Typography.self,
            Common.VariablesColors.self,
            Common.CommonConfig.self,
            // Figma
            Figma.Module.self,
            Figma.FigmaConfig.self,
            // iOS
            iOS.Module.self,
            iOS.HeicOptions.self,
            iOS.ColorsEntry.self,
            iOS.IconsEntry.self,
            iOS.ImagesEntry.self,
            iOS.Typography.self,
            iOS.iOSConfig.self,
            // Android
            Android.Module.self,
            Android.AndroidConfig.self,
            Android.ThemeAttributes.self,
            Android.NameTransform.self,
            Android.ColorsEntry.self,
            Android.IconsEntry.self,
            Android.ImagesEntry.self,
            Android.Typography.self,
            // Flutter
            Flutter.Module.self,
            Flutter.FlutterConfig.self,
            Flutter.ColorsEntry.self,
            Flutter.IconsEntry.self,
            Flutter.ImagesEntry.self,
            // Web
            Web.Module.self,
            Web.WebConfig.self,
            Web.ColorsEntry.self,
            Web.IconsEntry.self,
            Web.ImagesEntry.self,
        ])
    }()

    // swiftlint:enable identifier_name

    /// Evaluates a PKL configuration file and returns the typed ExFig module.
    /// - Parameter configPath: Path to the .pkl configuration file
    /// - Returns: Evaluated ExFig module with all platform configurations
    /// - Throws: `PKLError.configNotFound` if file doesn't exist,
    ///           or PklSwift evaluation errors on syntax/type issues
    public static func evaluate(configPath: URL) async throws -> ExFig.ModuleImpl {
        guard FileManager.default.fileExists(atPath: configPath.path) else {
            throw PKLError.configNotFound(path: configPath.path)
        }

        // CRITICAL: Must execute before withEvaluator(), which triggers TypeRegistry.get()
        // during decoding. registerPklTypes() has precondition(_shared == nil).
        _ = _typeRegistration

        var options = EvaluatorOptions.preconfigured
        options.allowedModules = allowedModules
        options.allowedResources = allowedResources

        return try await PklSwift.withEvaluator(options: options) { evaluator in
            try await evaluator.evaluateModule(
                source: .path(configPath.path),
                as: ExFig.ModuleImpl.self
            )
        }
    }
}
