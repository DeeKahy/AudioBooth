import Foundation

public struct ListeningStats: Codable {
  public let totalTime: Double
  public let days: [String: Double]
  public let dayOfWeek: [String: Double]
  public let today: Double
  public let recentSessions: [Session]?

  public struct Session: Codable {
    public let id: String
    public let libraryItemId: String
    public let displayTitle: String
    public let displayAuthor: String
    public let coverPath: String?
    public let timeListening: Double?
    public let updatedAt: Double
  }
}
