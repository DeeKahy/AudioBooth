import API
import Foundation

public struct Session {
  public let id: String
  public let itemID: String
  public let url: URL

  public init(id: String, itemID: String, url: URL) {
    self.id = id
    self.itemID = itemID
    self.url = url
  }

  public init?(from playSession: PlaySession) {
    guard let serverURL = Audiobookshelf.shared.authentication.serverURL else {
      return nil
    }

    let baseURL = serverURL.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    guard let url = URL(string: "\(baseURL)/public/session/\(playSession.id)") else {
      return nil
    }

    self.id = playSession.id
    self.itemID = playSession.libraryItemId
    self.url = url
  }

  public func url(for track: Track) -> URL {
    if let localPath = track.localPath {
      return localPath
    }
    return url.appendingPathComponent("track/\(track.index)")
  }
}
