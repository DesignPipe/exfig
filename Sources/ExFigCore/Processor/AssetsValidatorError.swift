import Foundation

enum AssetsValidatorError: LocalizedError {
    case badName(name: String)
    case countMismatch(light: Int, dark: Int)
    case countMismatchLightHighContrastColors(light: Int, lightHC: Int)
    case countMismatchDarkHighContrastColors(dark: Int, darkHC: Int)
    case foundDuplicate(assetName: String)
    case secondAssetsNotFoundInFirstPalette(assets: [String], firstAssetsName: String, secondAssetsName: String)
    case descriptionMismatch(assetName: String, light: String, dark: String)

    var errorDescription: String? {
        switch self {
        case let .badName(name):
            "Invalid asset name: \(name)"
        case let .countMismatch(light, dark):
            "Asset count mismatch: light=\(light), dark=\(dark)"
        case let .countMismatchLightHighContrastColors(light, lightHC):
            "Asset count mismatch: light=\(light), lightHC=\(lightHC)"
        case let .countMismatchDarkHighContrastColors(dark, darkHC):
            "Asset count mismatch: dark=\(dark), darkHC=\(darkHC)"
        case let .secondAssetsNotFoundInFirstPalette(assets, firstAssetsName, _):
            "Missing assets in \(firstAssetsName): \(assets.joined(separator: ", "))"
        case let .foundDuplicate(assetName):
            "Duplicate asset: \(assetName)"
        case let .descriptionMismatch(assetName, light, dark):
            "Description mismatch for \(assetName): light=\"\(light)\", dark=\"\(dark)\""
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .badName:
            "Rename asset using valid characters"
        case .countMismatch, .countMismatchLightHighContrastColors, .countMismatchDarkHighContrastColors:
            "Add missing assets to match theme counts"
        case .secondAssetsNotFoundInFirstPalette:
            "Add missing assets and publish to Team Library"
        case .foundDuplicate:
            "Remove duplicate assets with the same name"
        case .descriptionMismatch:
            "Update descriptions to match in both themes"
        }
    }
}
