import Foundation
import SwiftData

/// Alle gespeicherten Modelle an einer Stelle, damit App und Tests dasselbe Schema nutzen.
enum AppSchema {
    static var models: [any PersistentModel.Type] {
        [
            JobApplication.self, TimelineEntry.self, ApplicationEvent.self,
            ContactPerson.self, ApplicationDocument.self,
        ]
    }

    static func makeContainer(inMemory: Bool) throws -> ModelContainer {
        try ModelContainer(
            for: Schema(models),
            configurations: ModelConfiguration(isStoredInMemoryOnly: inMemory)
        )
    }
}
