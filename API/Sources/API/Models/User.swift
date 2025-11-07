import Foundation

public struct User: Codable, Sendable {
  public let mediaProgress: [MediaProgress]
  public let permissions: Permissions
}

extension User {
  public struct MediaProgress: Codable, Sendable {
    public let id: String
    public let libraryItemId: String
    public let progress: Double
    public let currentTime: Double
    public let lastUpdate: Int64

    public init(
      id: String, libraryItemId: String, progress: Double, currentTime: Double, lastUpdate: Int64
    ) {
      self.id = id
      self.libraryItemId = libraryItemId
      self.progress = progress
      self.currentTime = currentTime
      self.lastUpdate = lastUpdate
    }
  }

  public struct Permissions: Codable, Sendable {
    public let update: Bool
    public let delete: Bool
  }
}
