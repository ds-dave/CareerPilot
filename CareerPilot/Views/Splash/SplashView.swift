import SwiftUI

/// Die Start-Animation: Ring und Pfeil werden gezeichnet, dann erscheint der Schriftzug.
/// Nach rund drei Sekunden ruft sie `onFinished` auf; ein Klick überspringt sie.
struct SplashView: View {
    /// Gesamtdauer bis zum Übergang in die App.
    static let duration: Duration = .seconds(3)
    /// Bei "Bewegung reduzieren" bleibt das Logo nur kurz stehen.
    static let reducedMotionDuration: Duration = .milliseconds(1_200)

    let onFinished: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var appeared = false
    @State private var ring: CGFloat = 0
    @State private var shaft: CGFloat = 0
    @State private var head: CGFloat = 0
    @State private var word: CGFloat = 0
    @State private var hasFinished = false
    @State private var wordWidth: CGFloat = 0

    /// Größenfaktor gegenüber der Vorlage (104 pt Bildmarke, 68 pt Schrift).
    private let scale: CGFloat = 1.25

    var body: some View {
        ZStack {
            LogoPalette.background
                .ignoresSafeArea()

            // Die Gruppe liegt von Anfang an in ihrer Endposition. Zu Beginn ist sie um die halbe
            // Schriftbreite nach rechts verschoben, damit die Bildmarke allein in der Mitte steht und
            // beim Einblenden des Schriftzugs an ihren Platz gleitet.
            HStack(spacing: 28 * scale) {
                LogoMark(size: 104 * scale, ring: ring, shaft: shaft, head: head)
                    .scaleEffect(appeared ? 1 : 0.9)
                    .opacity(appeared ? 1 : 0)

                LogoWordmark(fontSize: 68 * scale)
                    .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { wordWidth = $0 }
                    .opacity(word)
                    .offset(x: (1 - word) * -18)
                    .mask(alignment: .leading) {
                        Rectangle()
                            .scaleEffect(x: max(word, 0.001), anchor: .leading)
                    }
            }
            .offset(x: (1 - word) * (wordWidth + 28 * scale) / 2)
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: finish)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("CareerPilot")
        .accessibilityHint("Tippen, um die Startanimation zu überspringen")
        .accessibilityAddTraits(.isButton)
        .task { await play() }
    }

    private func play() async {
        if reduceMotion {
            appeared = true
            ring = 1
            shaft = 1
            head = 1
            word = 1
            try? await Task.sleep(for: Self.reducedMotionDuration)
            finish()
            return
        }

        withAnimation(.easeOut(duration: 0.45)) { appeared = true }
        withAnimation(.easeInOut(duration: 1.0).delay(0.2)) { ring = 1 }
        withAnimation(.easeInOut(duration: 0.45).delay(1.05)) { shaft = 1 }
        withAnimation(.easeOut(duration: 0.3).delay(1.45)) { head = 1 }
        withAnimation(.easeOut(duration: 0.75).delay(1.6)) { word = 1 }

        try? await Task.sleep(for: Self.duration)
        finish()
    }

    private func finish() {
        guard !hasFinished else { return }
        hasFinished = true
        onFinished()
    }
}

/// Sorgt dafür, dass die Animation pro App-Start nur einmal läuft, auch wenn weitere Fenster geöffnet werden.
@MainActor
enum SplashGate {
    private static var hasPlayed = false

    static let preferenceKey = "showSplash"

    /// Gibt `true` zurück, wenn die Animation jetzt gezeigt werden soll, und merkt sich, dass sie lief.
    static func consume(isRunningTests: Bool) -> Bool {
        guard !hasPlayed else { return false }
        hasPlayed = true
        guard !isRunningTests else { return false }
        let defaults = UserDefaults.standard
        // `bool(forKey:)` versteht auch "YES"/"NO" aus Startargumenten; ohne Eintrag gilt: zeigen.
        return defaults.object(forKey: preferenceKey) == nil ? true : defaults.bool(forKey: preferenceKey)
    }
}
