import AppKit
import Testing

@testable import CareerPilot

@Suite("Schrift")
struct FontTests {
    @Test("Die mitgelieferte Schrift Manrope ist im App-Paket und lässt sich laden")
    func manropeIsAvailable() {
        FontRegistrar.registerBundledFonts()
        let font = NSFont(name: "Manrope", size: 20) ?? NSFont(name: "Manrope-Regular", size: 20)
        #expect(font != nil)
        #expect(font?.familyName == "Manrope")
    }
}
