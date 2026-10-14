import CoreTransferable
import Foundation
import UniformTypeIdentifiers

/// Was beim Ziehen einer Karte transportiert wird: nur die Kennung der Bewerbung.
struct CardDragItem: Codable, Transferable {
    let uuid: UUID

    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .json)
    }
}
