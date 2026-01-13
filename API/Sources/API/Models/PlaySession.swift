import Foundation

public struct PlaySession: Codable, Sendable {
  public let id: String
  public let userId: String
  public let libraryItemId: String
  public let currentTime: Double
  public let duration: Double
  public let audioTracks: [Book.Media.Track]?
  public let chapters: [Book.Media.Chapter]?
  public let libraryItem: Book

  public struct StreamingTrack {
    public var track: Book.Media.Track
    public var url: URL
  }
}
