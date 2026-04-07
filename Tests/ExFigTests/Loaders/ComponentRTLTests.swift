@testable import ExFigCLI
import FigmaAPI
import XCTest

// MARK: - Component RTL Detection Tests

final class ComponentRTLTests: XCTestCase {
    // MARK: - iconName

    func testIconName_regularComponent_usesOwnName() {
        let component = makeComponent(name: "arrow-left")
        XCTAssertEqual(component.iconName, "arrow-left")
    }

    func testIconName_variantComponent_usesComponentSetName() {
        let component = makeComponent(
            name: "RTL=Off",
            componentSetName: "arrow-left"
        )
        XCTAssertEqual(component.iconName, "arrow-left")
    }

    func testIconName_variantComponentWithMultipleProperties() {
        let component = makeComponent(
            name: "State=Default, RTL=Off",
            componentSetName: "new-orders"
        )
        XCTAssertEqual(component.iconName, "new-orders")
    }

    // MARK: - rtlVariantValue

    func testRTLVariantValue_simpleOff() {
        let component = makeComponent(name: "RTL=Off")
        XCTAssertEqual(component.rtlVariantValue(propertyName: "RTL"), "Off")
    }

    func testRTLVariantValue_simpleOn() {
        let component = makeComponent(name: "RTL=On")
        XCTAssertEqual(component.rtlVariantValue(propertyName: "RTL"), "On")
    }

    func testRTLVariantValue_multipleProperties() {
        let component = makeComponent(name: "State=Default, RTL=Off")
        XCTAssertEqual(component.rtlVariantValue(propertyName: "RTL"), "Off")
        XCTAssertEqual(component.rtlVariantValue(propertyName: "State"), "Default")
    }

    func testRTLVariantValue_noRTLProperty() {
        let component = makeComponent(name: "arrow-left")
        XCTAssertNil(component.rtlVariantValue(propertyName: "RTL"))
    }

    func testRTLVariantValue_customPropertyName() {
        let component = makeComponent(name: "Direction=RTL")
        XCTAssertEqual(component.rtlVariantValue(propertyName: "Direction"), "RTL")
        XCTAssertNil(component.rtlVariantValue(propertyName: "RTL"))
    }

    func testRTLVariantValue_whitespaceAroundEquals() {
        let component = makeComponent(name: "RTL = Off")
        XCTAssertEqual(component.rtlVariantValue(propertyName: "RTL"), "Off")
    }

    func testRTLVariantValue_whitespaceInMultipleProperties() {
        let component = makeComponent(name: "State = Default , RTL = On")
        XCTAssertEqual(component.rtlVariantValue(propertyName: "RTL"), "On")
        XCTAssertEqual(component.rtlVariantValue(propertyName: "State"), "Default")
    }

    // MARK: - shouldSkipAsRTLVariant

    func testShouldSkip_RTLOnVariant() {
        let component = makeComponent(name: "RTL=On")
        XCTAssertTrue(component.shouldSkipAsRTLVariant(propertyName: "RTL"))
    }

    func testShouldNotSkip_RTLOffVariant() {
        let component = makeComponent(name: "RTL=Off")
        XCTAssertFalse(component.shouldSkipAsRTLVariant(propertyName: "RTL"))
    }

    func testShouldNotSkip_regularComponent() {
        let component = makeComponent(name: "arrow-left")
        XCTAssertFalse(component.shouldSkipAsRTLVariant(propertyName: "RTL"))
    }

    func testShouldNotSkip_nilPropertyName() {
        let component = makeComponent(name: "RTL=On")
        XCTAssertFalse(component.shouldSkipAsRTLVariant(propertyName: nil))
    }

    func testShouldNotSkip_emptyPropertyName() {
        let component = makeComponent(name: "RTL=On")
        XCTAssertFalse(component.shouldSkipAsRTLVariant(propertyName: ""))
    }

    func testShouldSkip_RTLOnInMultipleProperties() {
        let component = makeComponent(name: "State=Default, RTL=On")
        XCTAssertTrue(component.shouldSkipAsRTLVariant(propertyName: "RTL"))
    }

    func testShouldSkip_customActiveValues_true() {
        let component = makeComponent(name: "RTL=true")
        XCTAssertTrue(component.shouldSkipAsRTLVariant(propertyName: "RTL", activeValues: ["true"]))
    }

    func testShouldNotSkip_customActiveValues_false() {
        let component = makeComponent(name: "RTL=false")
        XCTAssertFalse(component.shouldSkipAsRTLVariant(propertyName: "RTL", activeValues: ["true"]))
    }

    func testShouldSkip_customActiveValues_Yes() {
        let component = makeComponent(name: "RTL=Yes")
        XCTAssertTrue(component.shouldSkipAsRTLVariant(propertyName: "RTL", activeValues: ["Yes"]))
    }

    func testShouldNotSkip_customActiveValues_mismatch() {
        let component = makeComponent(name: "RTL=On")
        XCTAssertFalse(component.shouldSkipAsRTLVariant(propertyName: "RTL", activeValues: ["true"]))
    }

    func testShouldSkip_multipleActiveValues() {
        let component = makeComponent(name: "RTL=true")
        XCTAssertTrue(component.shouldSkipAsRTLVariant(propertyName: "RTL", activeValues: ["On", "true"]))
    }

    func testShouldSkip_nilActiveValues_defaultsToOn() {
        let component = makeComponent(name: "RTL=On")
        XCTAssertTrue(component.shouldSkipAsRTLVariant(propertyName: "RTL", activeValues: nil))
    }

    func testShouldNotSkip_nilActiveValues_trueNotSkipped() {
        let component = makeComponent(name: "RTL=true")
        XCTAssertFalse(component.shouldSkipAsRTLVariant(propertyName: "RTL", activeValues: nil))
    }

    // MARK: - useRTL

    func testUseRTL_variantPropertyPresent_returnsTrue() {
        let component = makeComponent(
            name: "RTL=Off",
            componentSetName: "arrow-left"
        )
        XCTAssertTrue(component.useRTL(rtlProperty: "RTL"))
    }

    func testUseRTL_variantPropertyNotPresent_fallsBackToDescription() {
        let component = makeComponent(name: "arrow-left", description: "rtl icon")
        XCTAssertTrue(component.useRTL(rtlProperty: "RTL"))
    }

    func testUseRTL_noVariantNoDescription_returnsFalse() {
        let component = makeComponent(name: "arrow-left")
        XCTAssertFalse(component.useRTL(rtlProperty: "RTL"))
    }

    func testUseRTL_nilRtlProperty_fallsBackToDescription() {
        let component = makeComponent(name: "arrow-left", description: "RTL support")
        XCTAssertTrue(component.useRTL(rtlProperty: nil))
    }

    func testUseRTL_nilRtlProperty_noDescription_returnsFalse() {
        let component = makeComponent(name: "arrow-left")
        XCTAssertFalse(component.useRTL(rtlProperty: nil))
    }

    func testUseRTL_variantOverridesDescription() {
        // Even if description doesn't mention RTL, variant property wins
        let component = makeComponent(
            name: "RTL=Off",
            description: "no mention of direction",
            componentSetName: "arrow-left"
        )
        XCTAssertTrue(component.useRTL(rtlProperty: "RTL"))
    }

    func testUseRTL_descriptionCaseInsensitive() {
        let component = makeComponent(name: "arrow-left", description: "This is an RTL icon")
        XCTAssertTrue(component.useRTL(rtlProperty: nil))
    }

    func testUseRTL_emptyStringFallsBackToDescription() {
        // Empty rtlProperty should behave like nil — fall back to description
        let component = makeComponent(name: "arrow-left", description: "rtl icon")
        XCTAssertTrue(component.useRTL(rtlProperty: ""))
    }

    func testUseRTL_emptyStringNoDescription_returnsFalse() {
        let component = makeComponent(name: "arrow-left")
        XCTAssertFalse(component.useRTL(rtlProperty: ""))
    }

    // MARK: - codeConnectNodeId

    func testCodeConnectNodeId_variantComponent_usesComponentSetNodeId() {
        let component = makeComponent(
            name: "RTL=Off",
            componentSetName: "arrow-left"
        )
        // Component set nodeId is "99:0", own nodeId is "1:0"
        XCTAssertEqual(component.codeConnectNodeId, "99:0")
    }

    func testCodeConnectNodeId_regularComponent_usesOwnNodeId() {
        let component = makeComponent(name: "arrow-left")
        XCTAssertEqual(component.codeConnectNodeId, "1:0")
    }

    func testCodeConnectNodeId_variantWithMultipleProperties_usesComponentSetNodeId() {
        let component = makeComponent(
            name: "State=Default, RTL=Off",
            componentSetName: "new-orders"
        )
        XCTAssertEqual(component.codeConnectNodeId, "99:0")
    }

    func testCodeConnectNodeId_componentSetWithNilNodeId_fallsBackToOwnNodeId() {
        // When containingComponentSet exists but has no nodeId (anomalous API response),
        // should fall back to component's own nodeId
        let component = makeComponent(
            name: "RTL=Off",
            componentSetName: "arrow-left",
            componentSetNodeId: nil
        )
        XCTAssertEqual(component.codeConnectNodeId, "1:0")
    }

    // MARK: - defaultRTLProperty

    func testDefaultRTLProperty() {
        XCTAssertEqual(Component.defaultRTLProperty, "RTL")
    }

    // MARK: - Helpers

    private func makeComponent(
        name: String,
        description: String? = nil,
        frameName: String = "Icons",
        componentSetName: String? = nil,
        componentSetNodeId: String? = "99:0"
    ) -> Component {
        let descriptionField = description.map { ", \"description\": \"\($0)\"" } ?? ""

        let componentSetField = if let componentSetName {
            if let componentSetNodeId {
                """
                , "containingComponentSet": { "nodeId": "\(componentSetNodeId)", "name": "\(componentSetName)" }
                """
            } else {
                """
                , "containingComponentSet": { "name": "\(componentSetName)" }
                """
            }
        } else {
            ""
        }

        let json = """
        {
            "key": "test-key",
            "node_id": "1:0",
            "name": "\(name)"\(descriptionField),
            "containing_frame": {
                "nodeId": "2:0",
                "name": "\(frameName)"\(componentSetField)
            }
        }
        """

        // swiftlint:disable:next force_try
        return try! JSONDecoder().decode(Component.self, from: Data(json.utf8))
    }
}
