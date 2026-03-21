// Code generated from Pkl module `ExFig`. DO NOT EDIT.
import PklSwift

public enum ExFig {}

public protocol ExFig_Module: PklRegisteredType, DynamicallyEquatable, Hashable, Sendable {
    var figma: Figma.FigmaConfig? { get }

    var common: Common.CommonConfig? { get }

    var ios: iOS.iOSConfig? { get }

    var android: Android.AndroidConfig? { get }

    var flutter: Flutter.FlutterConfig? { get }

    var web: Web.WebConfig? { get }
}

extension ExFig {
    public typealias Module = ExFig_Module

    /// ExFig configuration schema.
    ///
    /// ExFig exports colors, typography, icons, and images from Figma
    /// to iOS, Android, Flutter, and Web projects.
    ///
    /// Usage:
    /// ```pkl
    /// amends "package://pkg.pkl-lang.org/github.com/DesignPipe/exfig/exfig@2.8.0#/ExFig.pkl"
    ///
    /// figma {
    ///   lightFileId = "xxx"
    /// }
    ///
    /// ios {
    ///   xcodeprojPath = "MyApp.xcodeproj"
    ///   // ...
    /// }
    /// ```
    /// Configuration module that users amend to create their config files.
    public struct ModuleImpl: Module {
        public static let registeredIdentifier: String = "ExFig"

        /// Figma file configuration.
        /// Required for icons, images, typography, or legacy Styles API colors.
        /// Optional when using only Variables API for colors.
        public var figma: Figma.FigmaConfig?

        /// Common settings shared across all platforms.
        public var common: Common.CommonConfig?

        /// iOS platform configuration.
        public var ios: iOS.iOSConfig?

        /// Android platform configuration.
        public var android: Android.AndroidConfig?

        /// Flutter platform configuration.
        public var flutter: Flutter.FlutterConfig?

        /// Web platform configuration.
        public var web: Web.WebConfig?

        public init(
            figma: Figma.FigmaConfig?,
            common: Common.CommonConfig?,
            ios: iOS.iOSConfig?,
            android: Android.AndroidConfig?,
            flutter: Flutter.FlutterConfig?,
            web: Web.WebConfig?
        ) {
            self.figma = figma
            self.common = common
            self.ios = ios
            self.android = android
            self.flutter = flutter
            self.web = web
        }
    }
}
