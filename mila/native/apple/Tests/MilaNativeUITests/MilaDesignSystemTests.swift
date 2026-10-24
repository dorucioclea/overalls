import SwiftUI
import XCTest
@testable import MilaNativeUI

final class MilaDesignSystemTests: XCTestCase {
    func testLightThemeUsesFourMonochromeTokens() {
        XCTAssertEqual(MilaMonoTokens.light.text, .black)
        XCTAssertEqual(MilaMonoTokens.light.textAlt, Color(red: 0.4, green: 0.4, blue: 0.4))
        XCTAssertEqual(MilaMonoTokens.light.background, .white)
        XCTAssertEqual(MilaMonoTokens.light.backgroundAlt, Color(red: 0.933333, green: 0.933333, blue: 0.933333))
    }

    func testDarkThemeUsesFourMonochromeTokens() {
        XCTAssertEqual(MilaMonoTokens.dark.text, .white)
        XCTAssertEqual(MilaMonoTokens.dark.textAlt, Color(red: 0.666667, green: 0.666667, blue: 0.666667))
        XCTAssertEqual(MilaMonoTokens.dark.background, .black)
        XCTAssertEqual(MilaMonoTokens.dark.backgroundAlt, Color(red: 0.066667, green: 0.066667, blue: 0.066667))
    }

    func testLocaleDisplayNamesUseCanonicalCatalogLocales() {
        XCTAssertEqual(MilaStrings.localeDisplayName("fr_fr"), "Français")
        XCTAssertEqual(MilaStrings.localeDisplayName("he-IL"), "עברית")
        XCTAssertEqual(MilaStrings.localeDisplayName("unknown"), "English")
    }

    func testLocaleCanonicalizationNormalizesBCP47AndRejectsUnknown() {
        XCTAssertEqual(MilaStrings.canonicalLocale(" fr_fr "), "fr-FR")
        XCTAssertEqual(MilaStrings.canonicalLocale("AR"), "ar")
        XCTAssertEqual(MilaStrings.canonicalLocale("he-IL"), "he")
        XCTAssertEqual(MilaStrings.canonicalLocale("de-Latn-DE"), "en")
        XCTAssertEqual(MilaStrings.canonicalLocale("xx_YY"), "en")
        XCTAssertEqual(MilaStrings.canonicalLocale(String(repeating: "x", count: 65)), "en")
    }
}
