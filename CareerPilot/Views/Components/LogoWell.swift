import SwiftData
import SwiftUI
import UniformTypeIdentifiers

/// Das Logo-Feld im Kopf der Detailansicht: Klick öffnet ein Menü, Bilder lassen sich hineinziehen.
struct LogoWell: View {
    let application: JobApplication
    var size: CGFloat = 64

    @State private var isTargeted = false
    @State private var isShowingOptions = false
    @State private var message: String?

    var body: some View {
        Button {
            isShowingOptions = true
        } label: {
            CompanyLogoView(application: application, size: size)
                .overlay {
                    if isTargeted {
                        RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
                            .strokeBorder(Color.accentColor, lineWidth: 2)
                    }
                }
        }
        .buttonStyle(.plain)
        .popover(isPresented: $isShowingOptions, arrowEdge: .bottom) {
            options
        }
        .onDrop(of: [.image, .fileURL], isTargeted: $isTargeted, perform: handleDrop)
        .help("Logo ändern: Bild aus der Zwischenablage einfügen (⌘V), hineinziehen oder auswählen")
        .accessibilityLabel("Firmenlogo")
        .accessibilityHint("Öffnet Optionen, um das Logo zu ändern")
        .alert(
            "Logo nicht gesetzt",
            isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(message ?? "")
        }
    }

    private var options: some View {
        VStack(alignment: .leading, spacing: 2) {
            option("Aus Zwischenablage einfügen", systemImage: "doc.on.clipboard", action: pasteFromClipboard)
            option("Bild auswählen …", systemImage: "photo", action: chooseFile)
            if application.logoData != nil {
                Divider().padding(.vertical, 4)
                option("Logo entfernen", systemImage: "trash", role: .destructive) {
                    application.logoData = nil
                }
            }
            Text("Tipp: Mach einen Screenshot (⌃⇧⌘4) und füge ihn mit ⌘V ein.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.top, 8)
        }
        .padding(10)
        .frame(width: 280)
    }

    private func option(
        _ title: String, systemImage: String, role: ButtonRole? = nil, action: @escaping () -> Void
    ) -> some View {
        Button(role: role) {
            isShowingOptions = false
            action()
        } label: {
            Label(title, systemImage: systemImage)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: Aktionen

    private func pasteFromClipboard() {
        guard let data = LogoPasteboard.imageData() else {
            message = "In der Zwischenablage liegt kein Bild. Mach einen Screenshot (⌃⇧⌘4) oder kopiere ein Bild."
            return
        }
        apply(data)
    }

    private func chooseFile() {
        guard let url = FilePanels.open(types: [.image]) else { return }
        guard let data = LogoPasteboard.data(from: url) else {
            message = "Die Datei konnte nicht gelesen werden."
            return
        }
        apply(data)
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        LogoImporter.imageData(from: providers) { data in
            guard let data else {
                message = "Das abgelegte Objekt ist kein Bild."
                return
            }
            apply(data)
        }
        return true
    }

    private func apply(_ data: Data) {
        if !application.setLogo(from: data) {
            message = "Das Bild konnte nicht gelesen werden oder ist zu groß."
        }
    }
}
