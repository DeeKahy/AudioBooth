import Foundation

public struct ListeningStats: Codable {
  public let totalTime: Double
  public let items: [String: ListeningItem]
  public let days: [String: Double]
  public let dayOfWeek: [String: Double]
  public let today: Double
  public let recentSessions: [RecentSession]

  public struct ListeningItem: Codable {
    public let id: String
    public let timeListening: Double
    public let mediaMetadata: Book.Media.Metadata
  }

  public struct RecentSession: Codable {
    public let id: String
    public let userID: String
    public let libraryID: String
    public let libraryItemID: String
    public let bookID: String?
    public let episodeID: String?
    public let mediaType: String
    public let mediaMetadata: Book.Media.Metadata
    public let chapters: [String]
    public let displayTitle: String
    public let displayAuthor: String
    public let coverPath: String?
    public let duration: Double
    public let playMethod: Int
    public let mediaPlayer: String
    public let deviceInfo: DeviceInfo
    public let serverVersion: String
    public let date: String
    public let dayOfWeek: String
    public let timeListening: Double
    public let startTime: Double
    public let currentTime: Double
    public let startedAt: Int64
    public let updatedAt: Int64

    enum CodingKeys: String, CodingKey {
      case id
      case userID = "userId"
      case libraryID = "libraryId"
      case libraryItemID = "libraryItemId"
      case bookID = "bookId"
      case episodeID = "episodeId"
      case mediaType
      case mediaMetadata
      case chapters
      case displayTitle
      case displayAuthor
      case coverPath
      case duration
      case playMethod
      case mediaPlayer
      case deviceInfo
      case serverVersion
      case date
      case dayOfWeek
      case timeListening
      case startTime
      case currentTime
      case startedAt
      case updatedAt
    }

    public struct DeviceInfo: Codable {
      public let id: String
      public let userID: String
      public let deviceID: String
      public let ipAddress: String
      public let osName: String
      public let clientVersion: String
      public let clientName: String

      enum CodingKeys: String, CodingKey {
        case id
        case userID = "userId"
        case deviceID = "deviceId"
        case ipAddress
        case osName
        case clientVersion
        case clientName
      }
    }
  }
}
