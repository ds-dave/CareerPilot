import CoreText
import Foundation

/// Meldet die mitgelieferte Schrift (Manrope, SIL Open Font License) beim System an.
enum FontRegistrar {
    static func registerBundledFonts() {
        for name in ["Manrope"] {
            guard let url = Bundle.main.url(forResource: name, withExtension: "ttf") else { continue }
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }
}
