import SwiftUI

/// Farben des Logos.
enum LogoPalette {
    static let background = Color(red: 0x0E / 255, green: 0x11 / 255, blue: 0x16 / 255)
    static let ink = Color(red: 0xF7 / 255, green: 0xF7 / 255, blue: 0xF5 / 255)
    static let accent = Color(red: 0x7C / 255, green: 0x98 / 255, blue: 0xFF / 255)
}

/// Der Ring der Bildmarke: 270 Grad, die Lücke oben rechts gehört dem Pfeil.
/// Maße in einer 64er-Fläche, wie in der Logo-Vorlage.
private struct LogoRing: Shape {
    func path(in rect: CGRect) -> Path {
        let unit = rect.width / 64
        var path = Path()
        let center = CGPoint(x: 32 * unit, y: 32 * unit)
        var angle = -17.0
        var isFirst = true
        while angle <= 253.0001 {
            let radians = angle * .pi / 180
            let point = CGPoint(
                x: center.x + 24 * unit * cos(radians),
                y: center.y + 24 * unit * sin(radians)
            )
            if isFirst {
                path.move(to: point)
                isFirst = false
            } else {
                path.addLine(to: point)
            }
            angle += 0.5
        }
        return path
    }
}

/// Der Schaft des Pfeils.
private struct LogoArrowShaft: Shape {
    func path(in rect: CGRect) -> Path {
        let unit = rect.width / 64
        var path = Path()
        path.move(to: CGPoint(x: 23 * unit, y: 41 * unit))
        path.addLine(to: CGPoint(x: 50 * unit, y: 14 * unit))
        return path
    }
}

/// Die Spitze des Pfeils.
private struct LogoArrowHead: Shape {
    func path(in rect: CGRect) -> Path {
        let unit = rect.width / 64
        var path = Path()
        path.move(to: CGPoint(x: 37 * unit, y: 14 * unit))
        path.addLine(to: CGPoint(x: 50 * unit, y: 14 * unit))
        path.addLine(to: CGPoint(x: 50 * unit, y: 27 * unit))
        return path
    }
}

/// Die Bildmarke. Die drei Fortschrittswerte (0 bis 1) lassen Ring, Pfeilschaft und Pfeilspitze nacheinander
/// zeichnen; mit 1/1/1 ist es das fertige Logo.
struct LogoMark: View {
    var size: CGFloat = 104
    /// Farbe des Rings; der Pfeil bleibt immer im Markenblau.
    var ink: Color = LogoPalette.ink
    var ring: CGFloat = 1
    var shaft: CGFloat = 1
    var head: CGFloat = 1

    var body: some View {
        let lineWidth = 5 * size / 64
        let style = StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)
        ZStack {
            LogoRing()
                .trim(from: 0, to: ring)
                .stroke(ink, style: style)
            LogoArrowShaft()
                .trim(from: 0, to: shaft)
                .stroke(LogoPalette.accent, style: style)
            LogoArrowHead()
                .trim(from: 0, to: head)
                .stroke(LogoPalette.accent, style: style)
        }
        .frame(width: size, height: size)
        .accessibilityElement()
        .accessibilityLabel("CareerPilot Bildmarke")
    }
}

/// Der Schriftzug: "Career" in Medium, "Pilot" in Bold, wie in der Vorlage.
struct LogoWordmark: View {
    var fontSize: CGFloat = 68
    var color: Color = LogoPalette.ink

    var body: some View {
        (Text("Career").fontWeight(.medium) + Text("Pilot").fontWeight(.bold))
            .font(.custom("Manrope", size: fontSize))
            .tracking(-0.03 * fontSize)
            .foregroundStyle(color)
            .lineLimit(1)
            .fixedSize()
    }
}

/// Bildmarke und Schriftzug nebeneinander, in den Proportionen der Vorlage.
/// Die Textfarbe folgt dem Farbschema, damit das Logo auf hellem und dunklem Grund lesbar bleibt.
struct LogoLockup: View {
    /// Höhe der Bildmarke in Punkten.
    var markSize: CGFloat = 26

    var body: some View {
        // Vorlage: Bildmarke 104, Schrift 68, Abstand 28.
        let fontSize = markSize * 68 / 104
        HStack(spacing: markSize * 28 / 104) {
            LogoMark(size: markSize, ink: .primary)
            LogoWordmark(fontSize: fontSize, color: .primary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("CareerPilot")
    }
}
