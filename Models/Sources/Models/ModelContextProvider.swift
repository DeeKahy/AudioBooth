import Foundation
import OSLog
import SwiftData

@MainActor
public final class ModelContextProvider {
  public static let shared = ModelContextProvider()

  public let container: ModelContainer
  public let context: ModelContext

  private init() {
    let dbURL = URL.documentsDirectory.appending(path: "AudiobookshelfData.sqlite")
    let configuration = ModelConfiguration(url: dbURL, allowsSave: true)

    do {
      let schema = Schema(versionedSchema: AudiobookshelfSchema.self)
      self.container = try ModelContainer(for: schema, configurations: configuration)
      AppLogger.persistence.info("ModelContainer created successfully")
    } catch {
      AppLogger.persistence.error("Failed to create persistent model container: \(error)")
      AppLogger.persistence.info("Clearing data and creating fresh container...")

      try? FileManager.default.removeItem(at: dbURL)
      try? FileManager.default.removeItem(at: dbURL.appendingPathExtension("wal"))
      try? FileManager.default.removeItem(at: dbURL.appendingPathExtension("shm"))

      AppLogger.persistence.info("Cleared existing database files")

      do {
        let schema = Schema(versionedSchema: AudiobookshelfSchema.self)
        self.container = try ModelContainer(for: schema, configurations: configuration)
        AppLogger.persistence.info("Fresh container created successfully")
      } catch {
        AppLogger.persistence.error("Failed to create fresh container: \(error)")
        fatalError("Could not create ModelContainer even after clearing data")
      }
    }

    self.context = container.mainContext
  }
}
